#!/usr/bin/env python3
import os, subprocess, sys
mode = (sys.argv[1] if len(sys.argv) > 1 else "ci")  # "pr" or "ci"

def run(*args, ok=False):
    print("+", " ".join(args))
    r = subprocess.run(args)
    if not ok and r.returncode != 0:
        sys.exit(r.returncode)

run("terraform","fmt","-check","-recursive")
run("terraform","validate")

args = ["terraform","plan","-input=false","-no-color","-lock=false","-out","tfplan.bin"]
if mode == "pr":
    args += ["-refresh=false"]
run(*args)
print("Plan complete → tfplan.bin")
