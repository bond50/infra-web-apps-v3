# scripts/bootstrap_preflight.py
import os, re, sys

def need(name: str) -> str:
    v = os.environ.get(name, "")
    if not v:
        print(f"Missing required env: {name}")
        sys.exit(1)
    return v

aws_region = need("AWS_REGION")
need("AWS_ACCESS_KEY_ID")
need("AWS_SECRET_ACCESS_KEY")
need("GH_TOKEN_ADMIN")

if not re.match(r"^[a-z]+-[a-z]+-\d+$", aws_region):
    print(f"Invalid AWS_REGION: '{aws_region}' (expected 'us-east-1', 'eu-west-1', etc.)")
    sys.exit(1)

print("Preflight OK.")
