from lark import Transformer, v_args
from ast_nodes import *

@v_args(inline=True)
class ASTBuilder(Transformer):
    def program(self, *functions):
        return Program(list(functions))
    
    def function(self, return_type, name, params_or_block, *rest):
        if len(rest) == 0:
            return Function(str(return_type), str(name), [], params_or_block)
        else:
            return Function(str(return_type), str(name), params_or_block, rest[0])
        
    def block(self, *statements):
        return Block(list(statements))
    
    def var_decl(self, var_type, name, value=None):
        return VarDecl(str(var_type), str(name), value if value else 0)
    
    def assign(self, name, value):
        return Assign(str(name), value)
    
    def while_loop(self, condition, block):
        return WhileLoop(condition, block)
    
    def return_stmt(self, value):
        return ReturnStmt(value)

    def conditional(self, condition, if_block, *rest):
        else_block = rest[0] if len(rest) > 0 else None
        return Conditional(condition, if_block, else_block)
    
    def function_call(self, name, *args):
        real_args = [a for a in args if a is not None]
        return FunctionCall(str(name), real_args)
    
    def inline_psm(self, code_str):
        if isinstance(code_str, StringLiteral):
            return InlinePsm(code_str.value)
        return InlinePsm(str(code_str)[1:-1])
    
    def for_loop(self, init, cond, step, block):
        statements = []
        if init is not None:
            statements.append(init)

        if cond is None:
            cond = 1  

        body_stmts = list(block.statements)
        if step is not None:
            body_stmts.append(step)

        statements.append(WhileLoop(cond, Block(body_stmts)))
        return Block(statements)

    def assign_no_semi(self, name, value):
        return Assign(str(name), value)

    def _process_binop(self, *args):
        left = args[0]
        for i in range(1, len(args), 2):
            op = str(args[i])
            right = args[i+1]
            left = BinOp(left, op, right)

        return left
    
    def param_list(self, *items):
        params = []
        for i in range(0, len(items), 2):
            params.append((str(items[i]), str(items[i+1])))
        return params
    
    
    logic_or = _process_binop
    logic_and = _process_binop
    equality = _process_binop
    comparison = _process_binop
    term = _process_binop
    factor = _process_binop
    
    def NUMBER(self, n):
        return int(n)
    
    def CNAME(self, name):
        return str(name)
    
    def CHAR_LITERAL(self, char_str):
        raw_char = str(char_str)[1:-1]
        if raw_char == '\\n': return 10
        if raw_char == '\\0': return 0
        return ord(raw_char)
    
    def STRING(self, s):
        raw = str(s)[1:-1]
        decoded = (raw
                .replace('\\\\', '\x00')   # placeholder so \\ doesn't double-decode
                .replace('\\n', '\n')
                .replace('\\t', '\t')
                .replace('\\0', '\0')
                .replace('\\"', '"')
                .replace('\x00', '\\'))
        return StringLiteral(decoded)