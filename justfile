default:
  just --list

deploy machine ip="":
  #!/usr/bin/env sh
  set -euo pipefail
  case "{{machine}}" in
    mair|stud|nblap)
      sudo zsh -lc '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; darwin-rebuild switch --flake ".#{{machine}}"'
      ;;
    *)
      if [ -z "{{ip}}" ]; then
        sudo nixos-rebuild switch --fast --flake ".#{{machine}}"
      else
        # Build on remote host (required for cross-arch deployment from macOS to Linux)
        nixos-rebuild switch --fast --flake ".#{{machine}}" --use-remote-sudo --target-host "orther@{{ip}}" --build-host "orther@{{ip}}"
      fi
      ;;
  esac

up:
  nix flake update

lint:
  statix check .

gc:
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 7d && sudo nix store gc

repair:
  sudo nix-store --verify --check-contents --repair

sopsedit:
  @echo "Opening secrets/secrets.yaml with sops..."
  @SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt EDITOR=vim sops secrets/secrets.yaml

sopsrotate:
  #!/usr/bin/env sh
  export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
  for file in secrets/*; do sops --rotate --in-place "$file"; done

sopsupdate:
  #!/usr/bin/env sh
  export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
  for file in secrets/*; do sops updatekeys "$file"; done

build-iso:
  nix build .#nixosConfigurations.iso1chng.config.system.build.isoImage

fix-sop-keystxt:
  mkdir -p ~/.config/sops/age
  sudo nix-shell --extra-experimental-features flakes -p ssh-to-age --run "ssh-to-age -private-key -i /nix/secret/initrd/ssh_host_ed25519_key -o /home/orther/.config/sops/age/keys.txt"
  sudo chown -R orther:users ~/.config/sops/age

release version="":
  #!/usr/bin/env sh
  set -euo pipefail
  if [ -z "{{version}}" ]; then
    echo "Usage: just release vX.Y.Z" >&2
    exit 1
  fi
  case "{{version}}" in
    v[0-9]*.[0-9]*.[0-9]*) ;;
    *)
      echo "Version must be like v1.2.3" >&2
      exit 1
      ;;
  esac
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree not clean. Commit or stash first." >&2
    exit 1
  fi
  git tag -a "{{version}}" -m "Release {{version}}"
  git push origin "{{version}}"
fmt:
  nix fmt

check:
  nix flake check

# Deployment diagnostics and cleanup (remote NixOS machines only)

# Check if a deployment is running on a remote machine
deploy-status ip:
  @echo "=== Checking for running deployments on {{ip}} ==="
  @ssh orther@{{ip}} "ps aux | grep nixos-rebuild | grep -v grep || echo 'No deployments running'"
  @echo ""
  @echo "=== Checking systemd units ==="
  @ssh orther@{{ip}} "systemctl list-units --all | grep nixos-rebuild || echo 'No nixos-rebuild units'"

# Kill stuck deployment processes on a remote machine
deploy-clean ip:
  #!/usr/bin/env sh
  echo "=== Cleaning stuck deployment processes on {{ip}} ==="

  # Stop any nixos-rebuild systemd units
  echo "Stopping nixos-rebuild systemd units..."
  ssh orther@{{ip}} "sudo systemctl stop 'nixos-rebuild-*' 2>/dev/null || true" || true

  # Kill stuck processes
  echo "Killing stuck nixos-rebuild processes..."
  ssh orther@{{ip}} "sudo pkill -9 -f 'nixos-rebuild|systemd-run.*switch-to-configuration' || true" || true

  # Verify cleanup
  echo ""
  echo "=== Verification ==="
  ssh orther@{{ip}} "ps aux | grep nixos-rebuild | grep -v grep || echo '✓ No processes running'"

  echo ""
  echo "✓ Cleanup complete. You can now retry deployment."

# Check status of key services on a remote machine
service-status ip service="":
  #!/usr/bin/env sh
  set -euo pipefail
  if [ -z "{{service}}" ]; then
    echo "=== Checking all failed services on {{ip}} ==="
    ssh orther@{{ip}} "systemctl --failed --no-pager"
  else
    echo "=== Status of {{service}} on {{ip}} ==="
    ssh orther@{{ip}} "systemctl status {{service}} --no-pager -l | head -30"
  fi

# View recent logs for a service on a remote machine
service-logs ip service lines="50":
  @echo "=== Recent logs for {{service}} on {{ip}} ==="
  @ssh orther@{{ip}} "journalctl -u {{service}} -n {{lines}} --no-pager"

# Full diagnostic report for a remote machine
diagnose ip:
  #!/usr/bin/env sh
  set -euo pipefail
  echo "=== Diagnostic Report for {{ip}} ==="
  echo ""

  echo ">>> Running Deployments"
  just deploy-status {{ip}} || true
  echo ""

  echo ">>> Failed Services"
  ssh orther@{{ip}} "systemctl --failed --no-pager" || true
  echo ""

  echo ">>> Disk Usage"
  ssh orther@{{ip}} "df -h / /nix /nix/persist 2>/dev/null || df -h /"
  echo ""

  echo ">>> Recent System Logs (errors only)"
  ssh orther@{{ip}} "journalctl -p err -n 20 --no-pager" || true
