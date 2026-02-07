# Claude Code Orchestration Prompt

Copy the prompt below and paste it into a new Claude Code session from the goodlab repo root.

Before running this, complete Steps 1-6 of [HETZNER-SETUP-GUIDE.md](./HETZNER-SETUP-GUIDE.md) first (you need a running Hetzner VPS with SSH access).

---

## The Prompt

````markdown
## Task: Deploy OpenClaw to Hetzner Cloud VPS "claw"

I have a Hetzner Cloud CX33 VPS provisioned in Hillsboro, OR with Ubuntu 24.04.
The server IP is: **<REPLACE_WITH_YOUR_SERVER_IP>**

I need you to set up this server as a new NixOS machine called "claw" in my goodlab
flake, install NixOS via nixos-anywhere, and deploy the OpenClaw (clawdbot) service
with token optimizations and Ollama for heartbeat routing.

### Context

- This is a Nix flakes homelab repo. Read CLAUDE.md for full architecture overview.
- The deployment plan is in `docs/openclaw-deployment/PLAN.md`
- NixOS config templates are in `docs/openclaw-deployment/NIXOS-CONFIG.md`
- Token optimization details are in `docs/openclaw-deployment/TOKEN-OPTIMIZATION.md`
- The existing clawdbot config on `noir` is the reference: `hosts/noir/default.nix`
- Existing patterns to follow: `modules/nixos/base.nix`, `services/tailscale.nix`

### Step-by-step instructions

Work through these steps in order. Stop and ask me if anything fails or needs a
decision.

#### Phase 1: Create disko config and host skeleton

1. Create `hosts/claw/disko-config.nix` with a GPT partition layout for Hetzner Cloud:
   - 512MB EFI boot partition (vfat, /boot)
   - Remaining space as ext4 mounted at /nix
   - Root (/) on tmpfs with 2GB size for impermanence
   - Device is `/dev/sda` (standard Hetzner Cloud disk)

2. Create `hosts/claw/hardware-configuration.nix`:
   - Import `qemu-guest.nix` profile (Hetzner uses QEMU/KVM)
   - GRUB bootloader with EFI support, `efiInstallAsRemovable = true`
   - initrd modules: `ata_piix`, `uhci_hcd`, `virtio_pci`, `virtio_scsi`, `sd_mod`, `sr_mod`
   - Platform: `x86_64-linux`
   - Reference the disko-managed filesystems (don't duplicate them)

3. Create `hosts/claw/default.nix` following the template in
   `docs/openclaw-deployment/NIXOS-CONFIG.md` but with these adjustments:
   - Import `base`, `auto-update` modules (skip `remote-unlock` — no LUKS on VPS)
   - Import `services/tailscale.nix`, `services/_acme.nix`, `services/_nginx.nix`
   - Import `inputs.nix-clawdbot.nixosModules.clawdbot`
   - Use `server-base` home-manager module (not full `base`)
   - Configure all SOPS secrets for clawdbot (telegram, anthropic, gateway, brave, openrouter)
   - Full clawdbot service config with token optimizations (model routing, session init,
     heartbeat to ollama, budget controls)
   - Brave key injection systemd service (copy pattern from noir)
   - Networking: hostname "claw", useDHCP true, useNetworkd true, disable NetworkManager
   - Firewall: allow 80/443 globally, allow 18789 on tailscale0 only

4. Create `services/ollama.nix`:
   - Enable `services.ollama` with host `127.0.0.1`, port `11434`
   - `loadModels = ["llama3.2:3b"]`
   - Persist `/var/lib/ollama` via impermanence

5. Create `services/openclaw.nix` (shared Docker + persistence config):
   - Enable Docker with weekly autoPrune
   - Persist `/var/lib/clawdbot` via impermanence

#### Phase 2: Update flake and SOPS config

6. Add `claw` to `flake.nix`:
   - Add `nixosConfigurations.claw` (x86_64-linux, with nix-clawdbot overlay)
   - Add `nixosEval-claw` smoke test to `checks` (same pattern as noir/zinc/pie)

7. Add a placeholder age key for `claw` to `.sops.yaml`:
   - Use `age1placeholder000000000000000000000000000000000000000000000000` as the key
   - Add `*claw` to the creation_rules key_groups
   - We'll replace the placeholder with the real key after nixos-anywhere

8. Run `nix flake check` to verify the claw config evaluates cleanly.
   If there are errors, fix them before proceeding.

#### Phase 3: Install NixOS via nixos-anywhere

9. Run nixos-anywhere to install NixOS on the Hetzner VPS:
   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#claw \
     --disko-mode disko \
     root@<SERVER_IP>
   ```
   This will take 5-10 minutes. The server will reboot into NixOS automatically.

10. After reboot, verify SSH access:
    ```bash
    ssh orther@<SERVER_IP> "hostname && nixos-version"
    ```

#### Phase 4: SOPS key setup

11. Extract the real age key from the new server:
    ```bash
    ssh orther@<SERVER_IP> "sudo cat /etc/ssh/ssh_host_ed25519_key.pub" | nix shell nixpkgs#ssh-to-age -c ssh-to-age
    ```

12. Replace the placeholder in `.sops.yaml` with the real age key.

13. Tell me to run `just sopsupdate` manually (this requires my local SOPS age key).

#### Phase 5: Final deploy and verification

14. After I confirm SOPS is updated, deploy the full configuration:
    ```bash
    just deploy claw <SERVER_IP>
    ```

15. Verify services are running:
    ```bash
    ssh orther@<SERVER_IP> "systemctl status clawdbot-gateway ollama"
    ```

16. Create the new clawdbot workspace documents:
    - `clawdbot-documents/USER.md` (user context, from TOKEN-OPTIMIZATION.md)
    - `clawdbot-documents/IDENTITY.md` (agent identity, from TOKEN-OPTIMIZATION.md)
    - Update `clawdbot-documents/AGENTS.md` to reference VPS "claw" instead of "noir"

17. Commit all changes and push.

### Important notes

- Do NOT modify `hosts/noir/default.nix` yet — we'll disable clawdbot on noir
  only after confirming claw works
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
- [ ] Approve `claw` in [Tailscale Admin](https://login.tailscale.com/admin/machines)
- [ ] Send a test message to lildoofy_bot on Telegram
- [ ] Check API costs at [console.anthropic.com](https://console.anthropic.com) after 24 hours
- [ ] Once confirmed working, have Claude Code disable clawdbot on noir
