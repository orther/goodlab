# fix

Format the repo using the existing treefmt setup.

```bash
#!/usr/bin/env bash
set -euo pipefail

if command -v nix >/dev/null 2>&1; then
  nix fmt
else
  echo "nix is not available in PATH. Install Nix or enter a nix develop shell." >&2
  exit 1
fi
```
