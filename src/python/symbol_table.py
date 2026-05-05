
ARG_REGS = ['s0', 's1', 's2', 's3']
TEMP_REGS = ['s4', 's5', 's6', 's7', 's8', 's9']
SAVED_REGS = ['sA', 'sB', 'sC', 'sD', 'sE']

class SymbolTable:
    def __init__(self):
        self.scopes = [{}]

        self.arg_regs = ['s0', 's1', 's2', 's3']
        self.free_temp_regs = ['s4', 's5', 's6', 's7', 's8', 's9']
        self.free_saved_regs = ['sA', 'sB', 'sC', 'sD', 'sE']

    def enter_scope(self):
        self.scopes.append({})

    def exit_scope(self):
        if len(self.scopes) <= 1:
            raise Exception("Cannot exit the global scope.")
        
        popped_scope = self.scopes.pop()

        for var_name, register in popped_scope.items():
            if register in TEMP_REGS:
                self.free_temp_regs.append(register)
                self.free_temp_regs.sort()
            elif register in SAVED_REGS:
                self.free_saved_regs.append(register)
                self.free_saved_regs.sort()

    def declare_var(self, name):
        current_scope = self.scopes[-1]

        if name in current_scope:
            raise Exception(f"Variable '{name}' already declared.")
        
        if len(self.scopes) > 2 and self.free_temp_regs:
            reg = self.free_temp_regs.pop(0)

        elif self.free_saved_regs:
            reg = self.free_saved_regs.pop(0)

        elif self.free_temp_regs:
            reg = self.free_temp_regs.pop(0)

        else:
            raise Exception("Compiler Error: Out of PicoBlaze registers!")
        
        current_scope[name] = reg
        return reg
    
    def lookup_var(self, name):
        for scope in reversed(self.scopes):
            if name in scope:
                return scope[name]
        
        raise Exception(f"Undefined variable: '{name}'")