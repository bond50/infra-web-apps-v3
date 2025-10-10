#!/usr/bin/env python3
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
bootstrap_tf = (ROOT / "bootstrap" / "main.tf").read_text(encoding="utf-8")
imports_py   = (ROOT / "scripts" / "bootstrap_imports.py").read_text(encoding="utf-8")

# 1) find all github_actions_variable "tfvar_*" resource names in bootstrap/main.tf
tfvar_names = set(re.findall(
    r'resource\s+"github_actions_variable"\s+"(tfvar_[a-zA-Z0-9_]+)"', bootstrap_tf
))

# 2) find all keys present in tfvar_resources dict in bootstrap_imports.py
m = re.search(r"tfvar_resources\s*=\s*\{(.*?)\}\s*", imports_py, re.S)
if not m:
    print("ERROR: could not find tfvar_resources dict in scripts/bootstrap_imports.py")
    sys.exit(1)

dict_body = m.group(1)
import_keys = set(re.findall(
    r'"github_actions_variable\.(tfvar_[a-zA-Z0-9_]+)"\s*:', dict_body
))

missing = sorted(tfvar_names - import_keys)
extra   = sorted(import_keys - tfvar_names)

ok = True
if missing:
    print("❌ Missing tfvar entries in bootstrap_imports.py for:")
    for name in missing:
        print(f"  - github_actions_variable.{name}")
    ok = False

if extra:
    print("⚠️ import map has entries not present in bootstrap/main.tf (stale?):")
    for name in extra:
        print(f"  - github_actions_variable.{name}")

if not ok:
    sys.exit(1)

print("✅ bootstrap import map is in sync with bootstrap/main.tf")
