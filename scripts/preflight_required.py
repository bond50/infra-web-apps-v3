#!/usr/bin/env python3
import os, re, sys

mode = os.getenv("MODE", "ci")  # "bootstrap" or "ci"

def ensure(name, val):
    if not val:
        print(f"Missing required: {name}", file=sys.stderr)
        sys.exit(1)

aws_region = os.getenv("AWS_REGION")
ensure("AWS_REGION", aws_region)
if not re.match(r"^[a-z]+-[a-z]+-\d+$", aws_region):
    print(f"Invalid AWS_REGION: {aws_region}", file=sys.stderr)
    sys.exit(1)

if mode == "bootstrap":
    ensure("AWS_ACCESS_KEY_ID", os.getenv("AWS_ACCESS_KEY_ID"))
    ensure("AWS_SECRET_ACCESS_KEY", os.getenv("AWS_SECRET_ACCESS_KEY"))
    ensure("GH_TOKEN_ADMIN", os.getenv("GH_TOKEN_ADMIN"))
else:
    ensure("AWS_ROLE_ARN", os.getenv("AWS_ROLE_ARN"))
    ensure("TF_STATE_BUCKET", os.getenv("TF_STATE_BUCKET"))
    ensure("TF_STATE_KEY", os.getenv("TF_STATE_KEY"))

print("Preflight OK.")
