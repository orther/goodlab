# Hetzner Cloud Setup Guide

Step-by-step guide to provision a Hetzner Cloud VPS for the OpenClaw deployment.

## Prerequisites

- Credit card or PayPal for Hetzner billing
- SSH key pair on your local machine (`~/.ssh/id_ed25519`)
- Your goodlab repo cloned locally

## Step 1: Create Hetzner Cloud Account

1. Go to [https://accounts.hetzner.com/signUp](https://accounts.hetzner.com/signUp)
2. Register with email and password
3. Verify your email
4. Add payment method (credit card or PayPal)
5. You may need to verify identity — Hetzner occasionally requests ID verification for new accounts

## Step 2: Create a Cloud Project

1. Log into [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Click **"+ New project"**
3. Name it `goodlab`
4. Click into the project

## Step 3: Add Your SSH Key

1. In the project, go to **Security** (left sidebar) > **SSH Keys**
2. Click **"Add SSH Key"**
3. Paste your public key:
   ```bash
   # Run this on your Mac to copy your public key
   cat ~/.ssh/id_ed25519.pub | pbcopy
   ```
4. Name it something recognizable (e.g., `stud-macbook`)
5. Click **"Add SSH key"**

## Step 4: Create the Server

1. Go to **Servers** (left sidebar) > **"Add Server"**
2. Configure as follows:

| Setting | Value |
|---------|-------|
| **Location** | Hillsboro (us-west) |
| **Image** | Ubuntu 24.04 |
| **Type** | Shared vCPU > **CX33** (4 vCPU, 8 GB RAM, 80 GB NVMe) |
| **Networking** | Public IPv4 + IPv6 (default) |
| **SSH Keys** | Select the key you just added |
| **Volumes** | None |
| **Firewalls** | None (we'll use NixOS firewall) |
| **Backups** | Enable (+20%, ~$1.20/month) |
| **Name** | `claw` |

3. Click **"Create & Buy now"**
4. Wait ~30 seconds for the server to provision

## Step 5: Record the Server IP

1. Once created, note the **IPv4 address** from the server overview page
2. Save it — you'll need it for every subsequent step

```bash
# Example: export for convenience in this terminal session
export CLAW_IP=<your-server-ip>
```

## Step 6: Verify SSH Access

```bash
# Test SSH to the Ubuntu instance
ssh root@$CLAW_IP "hostname && uname -a"
```

You should see the Ubuntu hostname and kernel info. If this works, you're ready for NixOS installation.

## Step 7: Install NixOS via nixos-anywhere

This is where the Claude Code orchestration prompt takes over. From your goodlab repo directory:

1. Ensure you have `nix` installed locally with flakes enabled
2. The orchestration prompt (see [CLAUDE-CODE-PROMPT.md](./CLAUDE-CODE-PROMPT.md)) will guide Claude Code through:
   - Creating the disko configuration
   - Running `nixos-anywhere` to install NixOS
   - Setting up the host config in the flake
   - Deploying the full configuration

## Step 8: Tailscale Device Approval

After the first deploy, the VPS will try to join your Tailscale network:

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
2. Find the new `claw` device (it will show as pending)
3. Click **"..."** > **"Approve"**
4. Verify connectivity:
   ```bash
   # From your Mac
   ping claw  # Should resolve via Tailscale MagicDNS
   ```

## Step 9: Verify Everything Works

```bash
# SSH over Tailscale (once approved)
ssh orther@claw

# Check services
systemctl status clawdbot-gateway
systemctl status ollama

# Test Telegram bot
# Send a message to your bot on Telegram — it should respond
```

## Monthly Cost Summary

| Item | Cost |
|------|------|
| CX33 VPS (Hillsboro) | $5.99/month |
| Backups (+20%) | ~$1.20/month |
| **Total infrastructure** | **~$7.19/month** |

Billing is hourly with a monthly cap. If you delete the server before month-end, you only pay for hours used.

## Useful Hetzner Console Actions

| Action | How |
|--------|-----|
| **Resize server** | Servers > claw > Rescale (upgrade/downgrade anytime) |
| **View console** | Servers > claw > Console (browser-based VNC) |
| **Rebuild** | Servers > claw > Rebuild (reinstall OS — destructive) |
| **Snapshots** | Servers > claw > Snapshots (manual point-in-time backup) |
| **Power cycle** | Servers > claw > Power (restart/force off) |
| **Delete** | Servers > claw > Delete (stops all billing) |

## Troubleshooting

**"Permission denied" on SSH:**
- Ensure your SSH key was added in Step 3
- Try: `ssh -i ~/.ssh/id_ed25519 root@$CLAW_IP`

**Server not reachable after nixos-anywhere:**
- Use Hetzner Console (browser VNC) to check boot status
- nixos-anywhere can take 5-10 minutes to complete
- The server will reboot automatically after installation

**Tailscale not connecting:**
- Check that `tailscale-authkey` secret is properly configured in SOPS
- The auth key may be expired — generate a new one at [Tailscale Keys](https://login.tailscale.com/admin/settings/keys)

**Billing concerns:**
- Servers bill per hour up to the monthly cap
- Even powered-off servers still bill (you must **delete** to stop billing)
- Test with hourly billing, delete if something goes wrong, try again
