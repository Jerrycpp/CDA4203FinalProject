class Program:
    def __init__(self, functions):
        self.functions = functions

class Function:
    def __init__(self, return_type, name, params, block):
        self.return_type = return_type
        self.name = name
        self.params = params
        self.block = block

class Block:
    def __init__(self, statements):
        self.statements = statements

class VarDecl:
    def __init__(self, var_type, name, value):
        self.var_type = var_type
        self.name = name
        self.value = value

class Assign:
    def __init__(self, name, value):
        self.name = name
        self.value = value

class WhileLoop:
    def __init__(self, condition, block):
        self.condition = condition
        self.block = block

class BinOp:
    def __init__(self, left, op, right):
        self.left = left
        self.op = op
        self.right = right

class ReturnStmt:
    def __init__(self, value):
        self.value = value

class Conditional:
    def __init__(self, condition, if_block, else_block=None):
        self.condition = condition
        self.if_block = if_block
        self.else_block = else_block

class FunctionCall:
    def __init__(self, name, args):
        self.name = name
        self.args = args

class InlinePsm:
    def __init__(self, code):
        self.code = code

class StringLiteral:
    def __init__(self, value):
        self.value = value