#!/usr/bin/env python3

import yaml
import re
import sys
from pathlib import Path

if len(sys.argv) < 2:
    print("❌ Usage: convert_db_structure.py input.yml [output.yml]")
    sys.exit(1)

input_file = Path(sys.argv[1])
output_file = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(f"converted_{input_file.name}")

if not input_file.exists():
    print(f"❌ File not found: {input_file}")
    sys.exit(1)

# YAML Dumper with readable indentation
class IndentDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)

with input_file.open("r") as f:
    data = yaml.safe_load(f)

if "db" not in data or not isinstance(data["db"], list):
    print("❌ File has no 'db' variable, or it is not a list.")
    sys.exit(1)

converted = []
for entry in data["db"]:
    name = entry.get("name")
    pass_val = entry.get("pass")

    if not name or not pass_val:
        print(f"⚠️ Skipping invalid entry: {entry}")
        continue

    match = re.search(r"secret=([^:'\"]+):?([^'\")]+)?", pass_val)
    if not match:
        print(f"⚠️ Failed to parse pass: {pass_val}")
        continue

    path = match.group(1)
    key = match.group(2) if match.group(2) else "password"

    converted.append({
        "name": name,
        "vault_path": path,
        "vault_key": key
    })

# YAML serialization
yaml_string = yaml.dump(
    {"db": converted},
    Dumper=IndentDumper,
    sort_keys=False,
    default_flow_style=False,
    allow_unicode=True,
    width=100
)

# Prefix each line with 4 spaces
indented_yaml = "\n".join("    " + line if line.strip() != "" else "" for line in yaml_string.splitlines())

# Write output
with output_file.open("w") as f:
    f.write(indented_yaml + "\n")

print(f"✅ Done. Indentation applied. File: {output_file}")
