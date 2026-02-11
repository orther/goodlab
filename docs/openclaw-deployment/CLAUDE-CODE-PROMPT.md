# Claude Code Orchestration Prompt

Copy the prompt below and paste it into a new Claude Code session from the goodlab repo root.

Before running this, complete Steps 1-6 of [HETZNER-SETUP-GUIDE.md](./HETZNER-SETUP-GUIDE.md) first (you need a running Hetzner VPS with SSH access).

---

## The Prompt

````markdown
## Task: Deploy OpenClaw to Hetzner Cloud VPS "lildoofy"

I have a Hetzner Cloud CX33 VPS provisioned in Hillsboro, OR with Ubuntu 24.04.
The server IP is: **<REPLACE_WITH_YOUR_SERVER_IP>**

I need you to set up this server as a new NixOS machine called "lildoofy" in my goodlab
flake, install NixOS via nixos-anywhere, and deploy the OpenClaw (clawdbot) service
with token optimizations and Ollama for heartbeat routing.

### Context

- This is a Nix flakes homelab repo. Read CLAUDE.md for full architecture overview.
- The deployment plan is in `docs/openclaw-deployment/PLAN.md`
- NixOS config templates are in `docs/openclaw-deployment/NIXOS-CONFIG.md`
- Token optimization details are in `docs/openclaw-deployment/TOKEN-OPTIMIZATION.md`
- Reference config template: `docs/openclaw-deployment/NIXOS-CONFIG.md` (clawdbot was already removed from noir)
- Existing patterns to follow: `modules/nixos/base.nix`
- Isolation is mandatory:
  - dedicated `lildoofy` credentials only (no personal logins/tokens)
  - dedicated `lildoofy` SOPS file/rule
  - Tailscale-only ingress for SSH and gateway
  - no route advertisement from `lildoofy`

### Step-by-step instructions

Work through these steps in order. Stop and ask me if anything fails or needs a
decision.

#### Phase 1: Create disko config and host skeleton

1. Create `hosts/lildoofy/disko-config.nix` with a GPT partition layout for Hetzner Cloud:
   - 512MB EFI boot partition (vfat, /boot)
   - Remaining space as ext4 mounted at /nix
   - Root (/) on tmpfs with 2GB size for impermanence
   - Device is `/dev/sda` (standard Hetzner Cloud disk)

2. Create `hosts/lildoofy/hardware-configuration.nix`:
   - Import `qemu-guest.nix` profile (Hetzner uses QEMU/KVM)
   - GRUB bootloader with EFI support, `efiInstallAsRemovable = true`
   - initrd modules: `ata_piix`, `uhci_hcd`, `virtio_pci`, `virtio_scsi`, `sd_mod`, `sr_mod`
   - Platform: `x86_64-linux`
   - Reference the disko-managed filesystems (don't duplicate them)

3. Create `hosts/lildoofy/default.nix` following the template in
   `docs/openclaw-deployment/NIXOS-CONFIG.md` but with these adjustments:
   - Import `base`, `auto-update` modules (skip `remote-unlock` — no LUKS on VPS)
   - Import `inputs.nix-openclaw.nixosModules.clawdbot`
   - Use `server-base` home-manager module (not full `base`)
   - Override `sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]` (base.nix
     hardcodes a LUKS initrd path that won't exist on a VPS without LUKS)
   - Set `sops.defaultSopsFile = ./../../secrets/lildoofy-secrets.yaml`
   - Add `sops.secrets."user-password" = {}` (required by base.nix for `hashedPasswordFile`)
   - Add `sops.secrets."tailscale-authkey"` in host config
   - Configure all SOPS secrets for clawdbot (telegram, anthropic, gateway, brave, openrouter)
     using dedicated bot credentials only (not copied personal tokens)
   - Add the lildoofy admin pubkey to `users.users.orther.openssh.authorizedKeys.keys`
     (base.nix only has the personal key; the dedicated lildoofy admin key must be added too)
   - Full clawdbot service config with token optimizations (model routing, session init,
     heartbeat to ollama, budget controls)
   - Brave key injection systemd service (copy pattern from noir)
   - Configure `services.tailscale` locally in this host with:
     - `openFirewall = false`
     - `useRoutingFeatures = "client"` (no route advertisements)
     - no `--advertise-routes` flags
   - Networking: hostname "lildoofy", useDHCP true, useNetworkd true, disable NetworkManager
   - Set `services.openssh.openFirewall = lib.mkForce false`
   - Firewall: allow no global inbound ports; allow `22` and `18789` on `tailscale0` only

4. Create `services/ollama.nix`:
   - Enable `services.ollama` with host `127.0.0.1`, port `11434`
   - `loadModels = ["llama3.2:3b"]`
   - Persist `/var/lib/ollama` via impermanence

5. Create `services/openclaw.nix` (shared Docker + persistence config):
   - Enable Docker with weekly autoPrune
   - Persist `/var/lib/clawdbot` via impermanence

#### Phase 2: Update flake and SOPS config

6. Add `lildoofy` to `flake.nix`:
   - Add `nixosConfigurations.lildoofy` (x86_64-linux, with nix-openclaw overlay)
   - Add `nixosEval-lildoofy` smoke test to `checks` (same pattern as noir/zinc/pie)

7. Add a placeholder age key for `lildoofy` to `.sops.yaml`:
   - Use `age1placeholder000000000000000000000000000000000000000000000000` as the key
   - Add a dedicated creation_rule for `secrets/lildoofy-secrets.yaml` with recipients `*stud` and `*lildoofy`
     and place it **before** the shared catch-all rule
   - Do NOT add `*lildoofy` to the shared `secrets/[^/]+...` rule
   - We'll replace the placeholder with the real key after nixos-anywhere

8. Create `secrets/lildoofy-secrets.yaml` with only `lildoofy`-specific secrets
   (`user-password`, `tailscale-authkey`, `clawdbot/*`) and no unrelated machine secrets.

9. Run `nix flake check` to verify the lildoofy config evaluates cleanly.
   If there are errors, fix them before proceeding.

#### Phase 3: Install NixOS via nixos-anywhere

10. Run nixos-anywhere to install NixOS on the Hetzner VPS:
    Use the dedicated `~/.ssh/lildoofy_admin_ed25519` key (for example via `~/.ssh/config`
    host entry for `<SERVER_IP>`).

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#lildoofy \
  --disko-mode disko \
  root@<SERVER_IP>
```

This will take 5-10 minutes. The server will reboot into NixOS automatically.

11. After reboot, verify SSH access:
    ```bash
    ssh -i ~/.ssh/lildoofy_admin_ed25519 orther@<SERVER_IP> "hostname && nixos-version"
    ```

#### Phase 4: SOPS key setup

12. Extract the real age key from the new server:

    ```bash
    ssh -i ~/.ssh/lildoofy_admin_ed25519 orther@<SERVER_IP> "sudo cat /etc/ssh/ssh_host_ed25519_key.pub" | nix shell nixpkgs#ssh-to-age -c ssh-to-age
    ```

13. Replace the placeholder in `.sops.yaml` with the real age key.

14. Tell me to run `just sopsupdate` manually (this requires my local SOPS age key).

#### Phase 5: Final deploy and verification

15. After I confirm SOPS is updated, deploy the full configuration:

    ```bash
    just deploy lildoofy <SERVER_IP>
    ```

16. Verify services are running:

    ```bash
    ssh -i ~/.ssh/lildoofy_admin_ed25519 orther@<SERVER_IP> "systemctl status clawdbot-gateway ollama"
    ```

17. Create the new clawdbot workspace documents:
    - `clawdbot-documents/USER.md` (user context, from TOKEN-OPTIMIZATION.md)
    - `clawdbot-documents/IDENTITY.md` (agent identity, from TOKEN-OPTIMIZATION.md)
    - Note: `clawdbot-documents/AGENTS.md` is already updated to reference "lildoofy"

18. Commit all changes and push.

### Important notes

- Clawdbot was already removed from `hosts/noir/default.nix` — no changes needed there
- Do NOT reuse personal credentials — create dedicated bot/API credentials for `lildoofy`
- Do NOT expose public `80/443` unless we explicitly need a public web UI later
- Do NOT use shared `services/tailscale.nix` for this host (it advertises routes)
- Do NOT run `just sopsupdate` — tell me to do it manually since it needs my local key
- If nixos-anywhere fails, check the Hetzner Console (browser VNC) for boot errors
- The server's Tailscale will need manual approval — tell me when to do that
- Format with `nix fmt` before committing
- Run `nix flake check` after any flake.nix changes
````

---

## After Deployment Checklist

Once Claude Code finishes the prompt above, do these manual steps:

- [ ] Run `just sopsupdate` when prompted
- [ ] Approve `lildoofy` in [Tailscale Admin](https://login.tailscale.com/admin/machines)
- [ ] Verify SSH and gateway are reachable over Tailscale only
- [ ] Remove temporary public SSH rule in Hetzner firewall
- [ ] Send a test message to Lil Doofy on Telegram
- [ ] Check API costs at [console.anthropic.com](https://console.anthropic.com) after 24 hours
- [ ] Rotate legacy `noir` bot credentials (Telegram, Anthropic, Brave, OpenRouter)
