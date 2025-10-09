#!/usr/bin/env python3
import os, re, subprocess, sys

bucket = os.getenv("TF_STATE_BUCKET")
key    = os.getenv("TF_STATE_KEY")
region = os.getenv("AWS_REGION")

raw = os.getenv("GITHUB_HEAD_REF") or os.getenv("GITHUB_REF_NAME") or "main"
ws  = "branch-" + re.sub(r"[^a-zA-Z0-9-_]", "-", raw)

def run(*args):
    print("+", " ".join(args))
    subprocess.run(args, check=True)

run("terraform","init","-input=false",
    "-backend-config", f"bucket={bucket}",
    "-backend-config", f"key={key}",
    "-backend-config", f"region={region}",
    "-backend-config", "encrypt=true")
subprocess.run(["terraform","workspace","select", ws], check=False)
subprocess.run(["terraform","workspace","new", ws], check=False)
print(f"Workspace ready: {ws}")
