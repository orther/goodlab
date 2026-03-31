# verify

Run the deterministic verification steps for this repo.

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "== Nix flake checks =="
if command -v nix >/dev/null 2>&1; then
  nix flake check
else
  echo "nix is not available in PATH. Install Nix or enter a nix develop shell." >&2
  exit 1
fi
```
