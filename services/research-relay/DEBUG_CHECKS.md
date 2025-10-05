# GitHub Checks Debug Guide

If GitHub checks are still failing, use this guide to debug.

## Run Local Checks

### 1. Check Nix Syntax (if Nix is available)
```bash
# Parse all Nix files
for file in services/research-relay/*.nix machines/noir/configuration.nix machines/zinc/configuration.nix; do
  echo "Checking $file..."
  nix-instantiate --parse "$file" >/dev/null 2>&1 && echo "✓ $file" || echo "✗ $file FAILED"
done
```

### 2. Check Formatting (if tools available)
```bash
# Run alejandra
alejandra --check services/research-relay/*.nix machines/noir/configuration.nix machines/zinc/configuration.nix

# Run prettier on markdown
prettier --check services/research-relay/*.md

# Run shfmt if any shell scripts
shfmt -d services/research-relay/*.sh
```

### 3. Check with statix (if available)
```bash
statix check services/research-relay/
```

### 4. Check with deadnix (if available)
```bash
deadnix --fail services/research-relay/*.nix
```

### 5. Test NixOS Evaluation
```bash
# Test noir configuration
nix eval .#nixosConfigurations.noir.config.system.name

# Test zinc configuration
nix eval .#nixosConfigurations.zinc.config.system.name

# Full build test
nix build .#nixosConfigurations.noir.config.system.build.toplevel --dry-run
nix build .#nixosConfigurations.zinc.config.system.build.toplevel --dry-run
```

## Common Issues & Fixes

### Issue 1: "attribute 'X' missing"
**Symptom**: NixOS eval fails with missing attribute
**Fix**: Check that all options are defined before being used
```bash
# Verify option definitions
grep -r "options\.services\.researchRelay" services/research-relay/
```

### Issue 2: "infinite recursion encountered"
**Symptom**: Evaluation hangs or reports infinite recursion
**Fix**: Check for circular dependencies in config
```bash
# Look for self-references
grep -r "config\.services\.researchRelay" services/research-relay/
```

### Issue 3: "package 'X' does not exist"
**Symptom**: Build fails with unknown package
**Fix**: Check all package references
```bash
# List all package references
grep -rh "pkgs\.[a-zA-Z0-9_]*" services/research-relay/*.nix | \
  grep -o "pkgs\.[a-zA-Z0-9_]*" | sort -u
```

### Issue 4: "unused variable"
**Symptom**: deadnix reports unused let bindings
**Fix**: Remove or prefix with `_`
```bash
# Find let bindings
grep -A20 "^}: let" services/research-relay/*.nix
```

### Issue 5: Python package not found
**Symptom**: `python311Packages.X` doesn't exist
**Fix**: Comment out or use alternative
```bash
# Check Python package list
nix eval nixpkgs#python311Packages --apply builtins.attrNames | grep -i pypdf
```

## Verify File Integrity

```bash
# Check all files are valid UTF-8
for file in services/research-relay/*.nix; do
  iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1 || echo "✗ $file has encoding issues"
done

# Check for trailing whitespace
grep -r "[[:space:]]$" services/research-relay/*.nix && echo "✗ Trailing whitespace found"

# Check for tabs (should use spaces)
grep -r $'\t' services/research-relay/*.nix && echo "✗ Tabs found (use spaces)"

# Check balanced braces
for file in services/research-relay/*.nix; do
  open=$(grep -o '{' "$file" | wc -l)
  close=$(grep -o '}' "$file" | wc -l)
  if [ "$open" -ne "$close" ]; then
    echo "✗ $file: Unbalanced braces (open: $open, close: $close)"
  fi
done
```

## GitHub Actions Specific

### Check workflow syntax
```bash
# If using act (local GitHub Actions)
act -l

# Validate workflow files
yamllint .github/workflows/*.yml
```

### View actual error logs
Go to GitHub Actions tab in the PR and click on the failing check to see detailed logs.

Common log locations:
- Formatting: Look for "treefmt" output
- Statix: Look for "statix check" output
- Deadnix: Look for "deadnix" output
- NixOS Eval: Look for "nixosEval-noir" or "nixosEval-zinc" output

## Manual Validation Commands

If you don't have Nix installed, use these Python scripts:

### Check Syntax
```python
#!/usr/bin/env python3
import sys

for filepath in sys.argv[1:]:
    with open(filepath, 'r') as f:
        content = f.read()
    open_b = content.count('{')
    close_b = content.count('}')
    if open_b != close_b:
        print(f"✗ {filepath}: Unbalanced braces")
        sys.exit(1)
    print(f"✓ {filepath}")
```

### Check Module Structure
```python
#!/usr/bin/env python3
import re, sys

for filepath in sys.argv[1:]:
    with open(filepath, 'r') as f:
        content = f.read()

    has_options = 'options.services.researchRelay' in content
    has_mkif = re.search(r'config\s*=\s*lib\.mkIf', content)

    if has_options and not has_mkif:
        print(f"✗ {filepath}: Has options but no lib.mkIf")
        sys.exit(1)
    print(f"✓ {filepath}")
```

## Contact & Support

If checks continue to fail after trying these steps:

1. Check the actual GitHub Actions logs for specific error messages
2. Copy the exact error message
3. Search for that error in NixOS/nixpkgs issues
4. Ask in NixOS Discourse or Matrix channels

## Known Working State

Last known working commit: `<insert commit hash>`

Files modified in this PR:
- services/research-relay/_common-hardening.nix
- services/research-relay/age-gate.nix
- services/research-relay/btcpay.nix
- services/research-relay/odoo.nix
- services/research-relay/pdf-intake.nix
- services/research-relay/secrets.nix
- machines/noir/configuration.nix
- machines/zinc/configuration.nix (imports only)
- flake.nix (packages section)
