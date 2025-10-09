# scripts/export_tfvars_ci.py
import json, os, sys

GITHUB_ENV = os.environ.get("GITHUB_ENV")
if not GITHUB_ENV:
    print("Missing GITHUB_ENV")
    sys.exit(1)

def normalize_list(raw: str) -> str:
    """
    Accepts:
      - '["a","b"]' (valid JSON) -> pass through
      - [a,b] (no quotes) -> -> '["a","b"]'
      - '' -> ''
    Returns a JSON string or ''.
    """
    if not raw or raw.strip() == "":
        return ""
    s = raw.strip()
    # If already valid JSON array, keep it.
    try:
        arr = json.loads(s)
        if isinstance(arr, list):
            return json.dumps(arr)
    except Exception:
        pass
    # Convert [a,b] to ["a","b"]
    if s.startswith("[") and s.endswith("]"):
        inner = s[1:-1].strip()
        if not inner:
            return "[]"
        parts = [p.strip() for p in inner.split(",")]
        cleaned = []
        for p in parts:
            # Drop surrounding quotes if they exist
            if p.startswith('"') and p.endswith('"'): p = p[1:-1]
            cleaned.append(p)
        return json.dumps(cleaned)
    # Fallback: single value to list
    return json.dumps([s])

def write_env(k: str, v: str):
    if not v or v.strip() == "":
        return
    with open(GITHUB_ENV, "a", encoding="utf-8") as f:
        f.write(f"{k}={v}\n")
    print(f"export {k}={v}")

# Always export region (required)
aws_region = os.environ.get("AWS_REGION", "")
if not aws_region:
    print("ERROR: AWS_REGION not provided to export_tfvars_ci.py step.")
    sys.exit(1)
write_env("TF_VAR_region", aws_region)

# Scalar passthroughs
for name in [
    "project_name",
    "environment",
    "vpc_cidr",
    "enable_nat_gateway",
    "use_eip",
    "ssh_allowed_cidr",
]:
    raw = os.environ.get(f"RAW_TF_VAR_{name}", "")
    if raw:
        write_env(f"TF_VAR_{name}", raw)

# Lists that need normalization
for name in [
    "azs",
    "public_subnet_cidrs",
    "private_app_subnet_cidrs",
    "private_db_subnet_cidrs",
]:
    raw = os.environ.get(f"RAW_TF_VAR_{name}", "")
    if raw:
        write_env(f"TF_VAR_{name}", normalize_list(raw))
