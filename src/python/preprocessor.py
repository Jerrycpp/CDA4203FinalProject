import re
import os

def preprocess(filepath, macros=None):
    if macros == None:
        macros = {}
    
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Cannot find included file: {filepath}")

    with open(filepath, 'r') as f:
        lines = f.readlines()

    output = []

    for line in lines:
        stripped = line.strip()

        if stripped.startswith('#include'):
            match = re.match(r'#include\s+"([^"]+)"', stripped)
            if match:
                include_filename = match.group(1)
                output.append(preprocess(include_filename, macros))
            continue

        if stripped.startswith('#define'):
            parts = stripped.split(maxsplit=2)
            if len(parts) == 3:
                macro_name = parts[1]
                macro_value = parts[2]
                macros[macro_name] = macro_value
            continue

        processed_line = line
        for macro_name, macro_val in macros.items():
            processed_line = re.sub(rf'\b{macro_name}\b', macro_val, processed_line)
        
        output.append(processed_line)

    return "".join(output)