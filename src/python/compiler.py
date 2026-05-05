from preprocessor import preprocess
from lark import Lark
from transformer import ASTBuilder
from codegen import CodeGenerator
import os
import argparse



script_dir = os.path.dirname(os.path.abspath(__file__))
grammar_path = os.path.join(script_dir, "tiny_c.lark")

with open(grammar_path, "r") as f:
    grammar = f.read()

lark_parser = Lark(grammar, parser='lalr', start='program')

if __name__ == "__main__":
    cli_parser = argparse.ArgumentParser(description="A custom tiny-C compiler for the PicoBlaze architecture")
    cli_parser.add_argument("input_file", help="Path to the source .c file to compile")
    cli_parser.add_argument("-o", "--output", default="out.psm", help="Path to save the compiled .psm file")
    args = cli_parser.parse_args()

    try:
        print(f"Compiling {args.input_file}...")
        pure_c_code = preprocess(args.input_file)
        parse_tree = lark_parser.parse(pure_c_code)
        ast = ASTBuilder().transform(parse_tree)
        generator = CodeGenerator()
        final_assembly = generator.generate(ast)
        output_dir = os.path.dirname(args.output)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir)
        with open(args.output, "w") as f:
            f.write(final_assembly)
            
        print(f"Success! Assembly written to: {args.output}")
    except FileNotFoundError:
        print(f"Error: Could not find the input file '{args.input_file}'")
    except Exception as e:
        print(f"Compilation Failed: {e}")