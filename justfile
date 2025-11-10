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
