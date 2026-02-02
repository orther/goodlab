# commit-push-pr

Collects a quick status + diff summary, then commits and pushes.

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== Git status =="
git status -sb

echo ""
echo "== Diff summary =="
git --no-pager diff --stat

echo ""
if git diff --cached --quiet; then
  echo "No staged changes detected. Staging tracked changes..."
  git add -A
fi

if git diff --cached --quiet; then
  echo "Nothing to commit after staging. Aborting." >&2
  exit 1
fi

echo ""
read -r -p "Commit message: " message
if [ -z "${message}" ]; then
  echo "Commit message cannot be empty." >&2
  exit 1
fi

git commit -m "${message}"

echo ""
current_branch=$(git rev-parse --abbrev-ref HEAD)
if git remote get-url origin >/dev/null 2>&1; then
  git push -u origin "${current_branch}"
  echo ""
  if command -v gh >/dev/null 2>&1; then
    echo "Next: open a PR with: gh pr create --fill"
  else
    echo "Next: open a PR in your Git host for branch ${current_branch}."
  fi
else
  echo "No git remote named origin. Push skipped."
fi
```

Notes:
- This command stages tracked changes only and aborts if there is nothing to commit.
- It does not assume GitHub CLI is installed.
