# scripts/pr_branch_guard.py
import os, re, sys

if os.environ.get("BRANCH_GUARD", "").lower() == "off":
    print("BRANCH_GUARD=off → skipping branch guard.")
    sys.exit(0)

branch = os.environ.get("GITHUB_HEAD_REF") or os.environ.get("GITHUB_REF_NAME") or ""
print(f"Head branch: {branch}")

ok = (
    branch == "develop" or
    branch == "main" or
    re.match(r"^(feature|release|hotfix)\/.+$", branch) is not None
)

if not ok:
    print(f"❌ Branch '{branch}' violates policy: use feature/*, release/*, hotfix/*, develop, or main")
    sys.exit(1)

print("✅ Branch naming OK.")
