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
        nixos-rebuild switch --no-reexec --sudo --flake ".#{{machine}}"
      elif command -v nixos-rebuild >/dev/null 2>&1; then
        nixos-rebuild switch --no-reexec --flake ".#{{machine}}" --sudo --target-host "orther@{{ip}}" --build-host "orther@{{ip}}"
      else
        nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch --no-reexec --flake ".#{{machine}}" --sudo --target-host "orther@{{ip}}" --build-host "orther@{{ip}}"
      fi
      ;;
  esac

# Use for: firewall, routing, network interface, NAT changes.
# Arms a 10-minute auto-rollback to exact pre-deploy generation.
deploy-safe machine ip:
  #!/usr/bin/env sh
  set -euo pipefail
  PREV_GEN="$(ssh "orther@{{ip}}" 'readlink -f /nix/var/nix/profiles/system')"
  echo "Pre-deploy generation: $PREV_GEN"
  echo "Arming 10-min rollback timer..."
  ssh "orther@{{ip}}" "sudo systemd-run \
    --unit=nixos-auto-rollback \
    --on-active=10m \
    --property=Type=oneshot \
    $PREV_GEN/bin/switch-to-configuration switch"
  if ! just deploy {{machine}} {{ip}}; then
    echo "Deploy failed — cancelling rollback timer"
    ssh "orther@{{ip}}" "sudo systemctl stop nixos-auto-rollback.timer \
      nixos-auto-rollback.service; \
      sudo systemctl reset-failed nixos-auto-rollback.timer \
      nixos-auto-rollback.service || true"
    exit 1
  fi
  echo "--- Health check before confirming deploy ---"
  ssh "orther@{{ip}}" 'hostname && ip -brief addr && ip route && systemctl is-system-running'
  echo "--- Cancelling rollback timer ---"
  ssh "orther@{{ip}}" "sudo systemctl stop nixos-auto-rollback.timer \
    nixos-auto-rollback.service; \
    sudo systemctl reset-failed nixos-auto-rollback.timer \
    nixos-auto-rollback.service || true"
  echo "Deploy confirmed. Rollback timer cancelled."

# Use for: manually cancelling the rollback timer when you need >10 min to verify.
cancel-rollback ip:
  ssh "orther@{{ip}}" "sudo systemctl stop nixos-auto-rollback.timer \
    nixos-auto-rollback.service; \
    sudo systemctl reset-failed nixos-auto-rollback.timer \
    nixos-auto-rollback.service || true"
  echo "Rollback timer cancelled for {{ip}}."

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
