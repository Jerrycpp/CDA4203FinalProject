from symbol_table import SymbolTable
from ast_nodes import *

class CodeGenerator:
    def __init__(self):
        self.sym_tab = SymbolTable()
        self.assembly = []
        self.label_counter = 0
        self.needs_multiply = False
        self.needs_divide = False

    def emit(self, instruction):
        self.assembly.append(instruction)

    def generate(self, ast_root):
        self.visit(ast_root)
        self.inject_standard_library()
        return "\n".join(self.assembly)
    
    def visit(self, node):
        method_name = f'visit_{type(node).__name__}'
        visitor = getattr(self, method_name, self.generic_visit)
        return visitor(node)
    
    def generic_visit(self, node):
        raise Exception(f"No visit_{type(node).__name__} method defined!")
    
    def visit_Program(self, node):
        self.emit("; -- SYSTEM BOOT --")
        self.emit("LOAD sF, FF  ; Init Stack Pointer (sF)")
        self.emit("CALL main  ; Begin execution")
        self.emit("SYSTEM_HALT: JUMP SYSTEM_HALT")
        self.emit("; -------------\n")
        for func in node.functions:
            self.visit(func)

    def visit_Function(self, node):
        self.emit(f"{node.name}:")
        is_main = (node.name == "main")
        

        self.current_function_end = f"L_{node.name}_END"
        callee_saved = ['sA', 'sB', 'sC', 'sD', 'sE']

        if not is_main:
            self.emit("; Prolouge: Saving Callee-Saved Registers")
            for reg in callee_saved:
                self.push_reg(reg)

        self.sym_tab.enter_scope()
        for i, param in enumerate(node.params):
            if i >= 4:
                raise Exception(f"Function {node.name}: more than 4 params not supported")
            ptype, pname = param
            local_reg = self.sym_tab.declare_var(pname)
            arg_reg = self.sym_tab.arg_regs[i]
            self.emit(f"LOAD {local_reg}, {arg_reg}  ; param '{pname}' from {arg_reg}")
        self.visit(node.block)
        self.emit(f"{self.current_function_end}:")
        self.sym_tab.exit_scope()
        if not is_main:
            self.emit("; Epilouge")
            for reg in reversed(callee_saved):
                self.pop_reg(reg)
        self.emit("RETURN\n")

    def visit_Block(self, node):
        for statement in node.statements:
            ret_reg = self.visit(statement)
            if isinstance(statement, FunctionCall):
                self.sym_tab.free_temp_regs.append(ret_reg)
                self.sym_tab.free_temp_regs.sort()

    def visit_VarDecl(self, node):
        reg = self.sym_tab.declare_var(node.name)
        result_reg = self.get_value_in_temp_reg(node.value)
        self.emit(f"LOAD {reg}, {result_reg}  ; {node.name} = [result]")

        self.sym_tab.free_temp_regs.append(result_reg)
        self.sym_tab.free_temp_regs.sort()

    def visit_Assign(self, node):
        reg = self.sym_tab.lookup_var(node.name)
        result_reg = self.get_value_in_temp_reg(node.value)
        
        self.emit(f"LOAD {reg}, {result_reg}  ; {node.name} = [result]")
        
        self.sym_tab.free_temp_regs.append(result_reg)
        self.sym_tab.free_temp_regs.sort()


    def get_value_in_temp_reg(self, expr_node):
        if isinstance(expr_node, int):
            temp_reg = self.sym_tab.free_temp_regs.pop(0)
            hex_val = f"{expr_node:02X}"
            self.emit(f"LOAD {temp_reg}, {hex_val}")
            return temp_reg
        
        elif isinstance(expr_node, str):
            var_reg = self.sym_tab.lookup_var(expr_node)
            temp_reg = self.sym_tab.free_temp_regs.pop(0)
            self.emit(f"LOAD {temp_reg}, {var_reg}  ; Copy '{expr_node}' for math")
            return temp_reg
        
        elif isinstance(expr_node, BinOp):
            return self.visit_BinOp(expr_node)
        
        elif isinstance(expr_node, FunctionCall):
            return self.visit_FunctionCall(expr_node)
        
        else:
            raise Exception(f"Unknown expression type: {type(expr_node)}")
        
    def visit_BinOp(self, node):
        left_reg = self.get_value_in_temp_reg(node.left)
        right_reg = self.get_value_in_temp_reg(node.right)

        if node.op == '+':
            self.emit(f"ADD {left_reg}, {right_reg}")
        elif node.op == '-':
            self.emit(f"SUB {left_reg}, {right_reg}")
        elif node.op == '*':
            self.needs_multiply = True   # Trip the flag!
            self.emit(f"LOAD s0, {left_reg}  ; Prep multiplicand")
            self.emit(f"LOAD s1, {right_reg} ; Prep multiplier")
            self.emit(f"CALL __software_multiply")
            self.emit(f"LOAD {left_reg}, s0  ; Capture product")
            
        elif node.op == '/':
            self.needs_divide = True     # Trip the flag!
            self.emit(f"LOAD s0, {left_reg}  ; Prep dividend")
            self.emit(f"LOAD s1, {right_reg} ; Prep divisor")
            self.emit(f"CALL __software_divide")
            self.emit(f"LOAD {left_reg}, s0  ; Capture quotient")
        elif node.op in ['==', '!=', '<', '>', '<=', '>=']:
            # Grab a unique label ID for our jumps
            lbl = f"cmp_true_{self.label_counter}"
            self.label_counter += 1

            if node.op == '==':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"LOAD {left_reg}, 01  ; Assume True")
                self.emit(f"JUMP Z, {lbl}        ; If Zero flag is set, they are equal!")
                self.emit(f"LOAD {left_reg}, 00  ; If no jump, it was False")
                self.emit(f"{lbl}:")

            elif node.op == '!=':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"LOAD {left_reg}, 01")
                self.emit(f"JUMP NZ, {lbl}       ; If Not Zero flag, they are NOT equal")
                self.emit(f"LOAD {left_reg}, 00")
                self.emit(f"{lbl}:")

            elif node.op == '<':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"LOAD {left_reg}, 01")
                self.emit(f"JUMP C, {lbl}        ; Carry means Left < Right")
                self.emit(f"LOAD {left_reg}, 00")
                self.emit(f"{lbl}:")

            elif node.op == '>=':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"LOAD {left_reg}, 01")
                self.emit(f"JUMP NC, {lbl}       ; No Carry means Left >= Right")
                self.emit(f"LOAD {left_reg}, 00")
                self.emit(f"{lbl}:")

            elif node.op == '>':
                # Notice how right_reg and left_reg are SWAPPED in the COMPARE!
                self.emit(f"COMPARE {right_reg}, {left_reg}  ; Swapped!")
                self.emit(f"LOAD {left_reg}, 01")
                self.emit(f"JUMP C, {lbl}        ; Carry now means Right < Left (so Left > Right!)")
                self.emit(f"LOAD {left_reg}, 00")
                self.emit(f"{lbl}:")

            elif node.op == '<=':
                self.emit(f"COMPARE {right_reg}, {left_reg}  ; Swapped!")
                self.emit(f"LOAD {left_reg}, 01")
                self.emit(f"JUMP NC, {lbl}       ; No Carry means Right >= Left (so Left <= Right!)")
                self.emit(f"LOAD {left_reg}, 00")
                self.emit(f"{lbl}:")

        self.sym_tab.free_temp_regs.append(right_reg)
        self.sym_tab.free_temp_regs.sort()

        return left_reg
    
    def visit_WhileLoop(self, node):
        loop_id = self.label_counter
        self.label_counter += 1

        start_label = f"L_WHILE_START_{loop_id}"
        end_label = f"L_WHILE_END_{loop_id}"

        self.emit(f"\n{start_label}:")
        if isinstance(node.condition, int):
            if node.condition != 0:
                # Any non-zero number is an infinite loop!
                self.emit(f"; Infinite loop detected (while {node.condition})")
                # We don't evaluate or jump, just let it fall through to the block
            
            elif node.condition == 0:
                # Dead Code Elimination!
                self.emit("; Dead code eliminated (while 0)")
                # We completely skip visiting the block. We just return instantly!
                return
            
        elif isinstance(node.condition, BinOp):
            left_reg = self.get_value_in_temp_reg(node.condition.left)
            right_reg = self.get_value_in_temp_reg(node.condition.right)

            

            op = node.condition.op

            
            if op == '==':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"JUMP NZ, {end_label}  ; Jump away if NOT equal")
            elif op == '!=':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"JUMP Z, {end_label}   ; Jump away if EQUAL")

            
            elif op == '<':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"JUMP NC, {end_label}  ; Jump away if left >= right")
            elif op == '>=':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"JUMP C, {end_label}   ; Jump away if left < right")

            
            elif op == '>':
                
                self.emit(f"COMPARE {right_reg}, {left_reg}  ; OPERANDS SWAPPED!")
                self.emit(f"JUMP NC, {end_label}  ; Jump away if right >= left")
            elif op == '<=':
                
                self.emit(f"COMPARE {right_reg}, {left_reg}  ; OPERANDS SWAPPED!")
                self.emit(f"JUMP C, {end_label}   ; Jump away if right < left")

            else:
                self.emit(f"; Error: Unsupported operator {op}")

            self.sym_tab.free_temp_regs.append(left_reg)
            self.sym_tab.free_temp_regs.append(right_reg)
            self.sym_tab.free_temp_regs.sort()
        else:
            self.emit("; Error: Complex while conditions not yet implemented")
        
        self.sym_tab.enter_scope()
        self.visit(node.block)
        self.sym_tab.exit_scope()

        self.emit(f"JUMP {start_label}")

        self.emit(f"{end_label}:")

    def visit_Conditional(self, node):
        chain_id = self.label_counter
        self.label_counter += 1
        
        else_label = f"L_ELSE_{chain_id}"
        end_label = f"L_IF_END_{chain_id}"

        
        if isinstance(node.condition, BinOp):
            left_reg = self.get_value_in_temp_reg(node.condition.left)
            right_reg = self.get_value_in_temp_reg(node.condition.right)
            op = node.condition.op

            
            jump_target = else_label if node.else_block else end_label

            if op == '==':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"JUMP NZ, {jump_target}")
            elif op == '!=':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"JUMP Z, {jump_target}")
            elif op == '<':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"JUMP NC, {jump_target}")
            elif op == '>=':
                self.emit(f"COMPARE {left_reg}, {right_reg}")
                self.emit(f"JUMP C, {jump_target}")
            elif op == '>':
                self.emit(f"COMPARE {right_reg}, {left_reg}  ; Swapped!")
                self.emit(f"JUMP NC, {jump_target}")
            elif op == '<=':
                self.emit(f"COMPARE {right_reg}, {left_reg}  ; Swapped!")
                self.emit(f"JUMP C, {jump_target}")

            self.sym_tab.free_temp_regs.append(left_reg)
            self.sym_tab.free_temp_regs.append(right_reg)
            self.sym_tab.free_temp_regs.sort()

        
        self.emit(f"; --- IF BLOCK ---")
        self.sym_tab.enter_scope()
        self.visit(node.if_block)
        self.sym_tab.exit_scope()

        
        if node.else_block:
            self.emit(f"JUMP {end_label}  ; Skip the else block")

            
            self.emit(f"\n{else_label}:")
            self.emit(f"; --- ELSE BLOCK ---")
            self.sym_tab.enter_scope()
            self.visit(node.else_block)
            self.sym_tab.exit_scope()

        
        self.emit(f"\n{end_label}:")

    def visit_FunctionCall(self, node):
        # ---- Builtin: output(value, port) ----
        if node.name == "output":
            if len(node.args) != 2:
                raise Exception("output() takes exactly 2 arguments: value, port")
            if isinstance(node.args[0], StringLiteral):
                raise Exception("output() takes a single byte value, not a string. Use print() for strings.")
            value_reg = self.get_value_in_temp_reg(node.args[0])
            port_arg = node.args[1]
            if isinstance(port_arg, int):
                self.emit(f"OUTPUT {value_reg}, {port_arg:02X}  ; output to port {port_arg:02X}")
            else:
                port_reg = self.get_value_in_temp_reg(port_arg)
                self.emit(f"OUTPUT {value_reg}, ({port_reg})  ; output to dynamic port")
                self.sym_tab.free_temp_regs.append(port_reg)
                self.sym_tab.free_temp_regs.sort()
            self.sym_tab.free_temp_regs.append(value_reg)
            self.sym_tab.free_temp_regs.sort()
            # output() is conceptually void; hand back a 0 register to satisfy
            # the contract that every expression yields a register.
            ret = self.sym_tab.free_temp_regs.pop(0)
            self.emit(f"LOAD {ret}, 00  ; output() void return")
            return ret

        # ---- Builtin: input(port) -> value ----
        if node.name == "input":
            if len(node.args) != 1:
                raise Exception("input() takes exactly 1 argument: port")
            ret_reg = self.sym_tab.free_temp_regs.pop(0)
            port_arg = node.args[0]
            if isinstance(port_arg, int):
                self.emit(f"INPUT {ret_reg}, {port_arg:02X}  ; read from port {port_arg:02X}")
            else:
                port_reg = self.get_value_in_temp_reg(port_arg)
                self.emit(f"INPUT {ret_reg}, ({port_reg})  ; read from dynamic port")
                self.sym_tab.free_temp_regs.append(port_reg)
                self.sym_tab.free_temp_regs.sort()
            return ret_reg
        
        if node.name == "print":
            PRINT_PORT_DEFAULT = 1
            if len(node.args) not in (1, 2):
                raise Exception("print() takes 1 string, optionally with a port")
            if not isinstance(node.args[0], StringLiteral):
                raise Exception("print() first argument must be a string literal")
            text = node.args[0].value
            if len(node.args) == 2:
                if not isinstance(node.args[1], int):
                    raise Exception("print() port argument must be a constant int")
                port = node.args[1]
            else:
                port = PRINT_PORT_DEFAULT
            display = text.encode('unicode_escape').decode('ascii')
            self.emit(f"\n; -- print(\"{display}\") on port {port:02X} --")
            char_reg = self.sym_tab.free_temp_regs.pop(0)
            for ch in text:
                code = ord(ch)
                glyph = ch if 32 <= code < 127 else f"\\x{code:02X}"
                self.emit(f"LOAD {char_reg}, {code:02X}  ; '{glyph}'")
                self.emit(f"OUTPUT {char_reg}, {port:02X}")
            self.sym_tab.free_temp_regs.append(char_reg)
            self.sym_tab.free_temp_regs.sort()
            self.emit(f"; -- end print --\n")
            ret = self.sym_tab.free_temp_regs.pop(0)
            self.emit(f"LOAD {ret}, 00  ; print() void return")
            return ret




        self.emit(f"\n; -- Calling {node.name}() --")
        for i, arg_expr in enumerate(node.args):
            if i > 3:
                self.emit("; Error: We currently only support 4 arguments")

            result_reg = self.get_value_in_temp_reg(arg_expr)
            arg_reg = self.sym_tab.arg_regs[i]
            self.emit(f"LOAD {arg_reg}, {result_reg}  ; Load arg {i}")
            self.sym_tab.free_temp_regs.append(result_reg)
            self.sym_tab.free_temp_regs.sort()

        self.emit(f"CALL {node.name}")
        ret_temp = self.sym_tab.free_temp_regs.pop(0)
        self.emit(f"LOAD {ret_temp}, s0  ; Capture return value from {node.name}")
        self.emit(f"; -- End Call -- \n")
        return ret_temp
    
    def visit_InlinePsm(self, node):
        self.emit(f"{node.code}  ; [Inline Assembly Injected]")

    def push_reg(self, reg):
        self.emit(f"STORE {reg}, (sF)  ; Push {reg} to stack")
        self.emit("SUB sF, 01    ; Move SP down")

    def pop_reg(self, reg):
        self.emit("ADD sF, 01    ; Move SP up")
        self.emit(f"FETCH {reg}, (sF)  ; Pop {reg} from stack")


    def inject_standard_library(self):
        # If the C code never used * or /, exit immediately! (Dead Code Elimination)
        if not self.needs_multiply and not self.needs_divide:
            return

        self.emit("\n; ========================================")
        self.emit(";        TINY C STANDARD LIBRARY          ")
        self.emit("; ========================================")
        
        if self.needs_multiply:
            self.emit("__software_multiply:")
            self.emit("LOAD s2, 08      ; Loop counter (8 bits)")
            self.emit("LOAD s3, 00      ; Accumulator (Holds final product)")
            self.emit("mul_loop:")
            self.emit("SR0 s1           ; Shift multiplier right. LSB goes to Carry flag.")
            self.emit("JUMP NC, mul_skip ; If Carry is 0, don't add")
            self.emit("ADD s3, s0       ; If Carry is 1, add multiplicand")
            self.emit("mul_skip:")
            self.emit("SL0 s0           ; Shift multiplicand left")
            self.emit("SUB s2, 01       ; Decrement counter")
            self.emit("JUMP NZ, mul_loop ; Loop until 8 bits are processed")
            self.emit("LOAD s0, s3      ; Move result to return register (s0)")
            self.emit("RETURN\n")

        if self.needs_divide:
            self.emit("__software_divide:")
            self.emit("COMPARE s1, 00   ; Safety check: Divide by zero")
            self.emit("JUMP Z, div_end  ; If divisor is 0, just return 0 to prevent infinite loop")
            self.emit("LOAD s2, 08      ; Loop counter (8 bits)")
            self.emit("LOAD s3, 00      ; Remainder accumulator")
            self.emit("div_loop:")
            self.emit("SL0 s0           ; Shift Dividend left")
            self.emit("SLA s3           ; Shift Carry into Remainder")
            self.emit("COMPARE s3, s1   ; Can we subtract Divisor from Remainder?")
            self.emit("JUMP C, div_skip ; Skip subtraction if Remainder < Divisor")
            self.emit("SUB s3, s1       ; Remainder = Remainder - Divisor")
            self.emit("ADD s0, 01       ; Set LSB of Dividend (This builds the Quotient)")
            self.emit("div_skip:")
            self.emit("SUB s2, 01       ; Decrement counter")
            self.emit("JUMP NZ, div_loop")
            self.emit("div_end:")
            self.emit("RETURN\n")

    def visit_ReturnStmt(self, node):
        result_reg = self.get_value_in_temp_reg(node.value)
        self.emit(f"LOAD s0, {result_reg}  ; return value")
        self.sym_tab.free_temp_regs.append(result_reg)
        self.sym_tab.free_temp_regs.sort()
        self.emit(f"JUMP {self.current_function_end}")

    

    

    