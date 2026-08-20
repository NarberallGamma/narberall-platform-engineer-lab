#!/usr/bin/env python3

import yaml
import re
import sys
from pathlib import Path

if len(sys.argv) < 2:
    print("❌ Использование: convert_db_structure.py input.yml [output.yml]")
    sys.exit(1)

input_file = Path(sys.argv[1])
output_file = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(f"converted_{input_file.name}")

if not input_file.exists():
    print(f"❌ Файл не найден: {input_file}")
    sys.exit(1)

# YAML Dumper с читаемыми отступами
class IndentDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)

with input_file.open("r") as f:
    data = yaml.safe_load(f)

if "db" not in data or not isinstance(data["db"], list):
    print("❌ В файле нет переменной 'db' или она не является списком.")
    sys.exit(1)

converted = []
for entry in data["db"]:
    name = entry.get("name")
    pass_val = entry.get("pass")

    if not name or not pass_val:
        print(f"⚠️ Пропускаем некорректную запись: {entry}")
        continue

    match = re.search(r"secret=([^:'\"]+):?([^'\")]+)?", pass_val)
    if not match:
        print(f"⚠️ Не удалось разобрать pass: {pass_val}")
        continue

    path = match.group(1)
    key = match.group(2) if match.group(2) else "password"

    converted.append({
        "name": name,
        "vault_path": path,
        "vault_key": key
    })

# Сериализация YAML
yaml_string = yaml.dump(
    {"db": converted},
    Dumper=IndentDumper,
    sort_keys=False,
    default_flow_style=False,
    allow_unicode=True,
    width=100
)

# Добавляем 4 пробела к каждой строке
indented_yaml = "\n".join("    " + line if line.strip() != "" else "" for line in yaml_string.splitlines())

# Сохраняем
with output_file.open("w") as f:
    f.write(indented_yaml + "\n")

print(f"✅ Готово. Отступы добавлены. Файл: {output_file}")
