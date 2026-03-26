# Zinc Router — Recovery Runbook

Emergency reference for when zinc (condo router) stops working after a config deploy.

## Network Topology (for orientation)

```
Spectrum Modem (CM1100)
  └─ zinc enp1s0 (WAN) ── 76.88.x.x (DHCP from ISP)
       ↓ NAT
     zinc enp2s0 (LAN) ── 10.0.0.1/24
       └─ USW 24 PoE (10.0.0.2, core switch)
            ├─ U6 Pro (10.0.0.4, Kitchen AP)
            ├─ U6 Lite (10.0.0.5, Master Bedroom AP)
            └─ stud (10.0.0.30 wired / 10.0.0.50 wifi)

     zinc tailscale0 ── 100.100.101.31
     zinc enp4s0 (Mgmt) ── 192.168.254.1/24 (isolated, unused)
```

## Decision Tree

```
Can you SSH to zinc?
├─ YES (via LAN 10.0.0.1 or Tailscale 100.100.101.31)
│   └─ Go to: "Recovery via SSH" below
│
├─ NO — but stud still has an IP on 10.0.0.x
│   └─ zinc is up but SSH/firewall is broken
│   └─ Go to: "Recovery via Physical Console"
│
└─ NO — stud has no IP at all
    └─ zinc is down, DHCP/routing broken, or zinc didn't boot
    └─ Go to: "Recovery via Physical Console"
```

## Recovery via SSH

If you can reach zinc over SSH (LAN or Tailscale), you can roll back without rebooting.

### Roll back to previous NixOS generation

```bash
# List available generations
ssh orther@10.0.0.1 "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system"

# Switch to the previous generation (instant, no reboot)
ssh orther@10.0.0.1 "sudo /nix/var/nix/profiles/system-N-link/bin/switch-to-configuration switch"
# Replace N with the generation number you want (usually current minus 1)

# Or use the shorthand — switch to whatever "system" pointed to before your deploy:
ssh orther@10.0.0.1 "sudo /run/current-system/bin/switch-to-configuration switch"
```

**Note:** `switch-to-configuration switch` reactivates all systemd services immediately.
It does NOT reboot. Network should recover within seconds.

### Check what generation is active

```bash
ssh orther@10.0.0.1 "readlink -f /nix/var/nix/profiles/system"
```

### If deploy-safe was used

The rollback timer fires automatically after 10 minutes. If SSH dropped mid-deploy,
just wait — the previous generation will be restored. Reconnect after 10 minutes.

## Recovery via Physical Console

If you cannot SSH into zinc at all, you need physical access.

### What you need

- A monitor with HDMI (zinc has HDMI out)
- A USB keyboard
- Both are in the closet where zinc lives

### Option A: Reboot into previous generation (safest)

1. Connect monitor + keyboard to zinc
2. Reboot: hold power button ~5 seconds, then press again to power on
3. At the **systemd-boot menu** (10-second timeout), select a previous generation
4. Zinc boots with the old config — network should come back
5. Fix the broken config in the repo, redeploy

**Note:** LUKS decryption is automatic via keyfile — no passphrase needed during boot.

### Option B: Roll back without rebooting

1. Connect monitor + keyboard to zinc
2. Log in as `orther` (password is the SOPS-managed one; if you don't remember it, reboot instead)
3. Run:
   ```bash
   sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
   sudo /nix/var/nix/profiles/system-N-link/bin/switch-to-configuration switch
   ```

## Getting Internet on Stud Without Zinc

If zinc is completely down and you need internet to fix things:

### Phone Hotspot Method

1. **iPhone:** Settings > Personal Hotspot > Allow Others to Connect
2. **Stud:** System Settings > Wi-Fi > Connect to your iPhone hotspot
3. Stud now has internet via phone — you can research, pull packages, etc.
4. You can still SSH to zinc over LAN if zinc is up but NAT/WAN is broken:
   - Stud's ethernet (10.0.0.30) can still reach zinc (10.0.0.1) on the LAN
   - Even without WAN, the LAN switch keeps working

### Direct Ethernet to Modem (bypass zinc entirely)

1. Unplug the ethernet cable from zinc's enp1s0 (WAN port, port 1)
2. Plug it directly into stud's ethernet port
3. Stud gets a public IP via DHCP from Spectrum modem
4. You now have full internet, but no LAN (other devices are isolated)
5. **Remember to plug it back into zinc when done**

## Useful Diagnostic Commands

Run these from stud via `ssh orther@10.0.0.1` (or on zinc's physical console).

### Is zinc alive?

```bash
# From stud (LAN)
ping 10.0.0.1

# From stud (Tailscale)
ping 100.100.101.31
```

### Network basics

```bash
# What IPs does zinc have?
ip -brief addr

# Is WAN up? Does zinc have a public IP?
ip addr show enp1s0

# Can zinc reach the internet?
ping -c 3 1.1.1.1

# Is routing working?
ip route show
# Should show: default via 76.88.x.1 dev enp1s0

# Is NAT working? (iptables — current)
sudo iptables -t nat -L POSTROUTING -n -v
# Should show MASQUERADE rule on enp1s0

# Is NAT working? (nftables — after Change 7 migration)
# sudo nft list ruleset | grep -A5 masquerade
```

### DNS

```bash
# Is dnsmasq running?
systemctl status dnsmasq

# Can zinc resolve DNS?
dig @127.0.0.1 google.com      # via dnsmasq (if running)
dig @1.1.1.1 google.com        # direct to Cloudflare (bypasses dnsmasq)

# From stud — can LAN DNS resolve?
dig @10.0.0.1 google.com
```

### DHCP

```bash
# Is Kea running?
systemctl status kea-dhcp4-server

# Check active leases
cat /var/lib/kea/dhcp4.leases

# From stud — release and renew DHCP lease
sudo ipconfig set en0 DHCP     # macOS ethernet (adjust interface name)
```

### Services

```bash
# All running services
systemctl list-units --type=service --state=running

# Any failed services?
systemctl list-units --type=service --state=failed

# Restart a specific service
sudo systemctl restart dnsmasq
sudo systemctl restart kea-dhcp4-server
sudo systemctl restart tailscaled

# Check what's listening
ss -tlnp    # TCP
ss -ulnp    # UDP
```

### Firewall

```bash
# Current firewall rules (iptables — current)
sudo iptables -L -n -v
sudo iptables -t nat -L -n -v

# Current firewall rules (nftables — after Change 7 migration)
# sudo nft list ruleset

# Check if a port is open (from stud)
nc -zv 10.0.0.1 22      # SSH
nc -zv 10.0.0.1 53      # DNS
```

### Logs

```bash
# Recent errors (most useful single command)
sudo journalctl -p err --no-pager -n 50

# Specific service logs
sudo journalctl -u dnsmasq --no-pager -n 30
sudo journalctl -u kea-dhcp4-server --no-pager -n 30
sudo journalctl -u sshd --no-pager -n 30
sudo journalctl -u tailscaled --no-pager -n 30

# Kernel messages (hardware/driver issues)
sudo dmesg | tail -30
```

### Tailscale

```bash
tailscale status           # Is it connected?
tailscale ping stud        # Can it reach your desktop?
sudo systemctl restart tailscaled   # Restart if stuck
```

## Per-Change Recovery Reference

Quick reference for what might break with each hardening change and how to fix it.

### Change 1: Kernel sysctl hardening

**Symptom:** Devices can't get packets through zinc (unlikely).
**Cause:** `rp_filter=1` (strict mode) dropping packets with unexpected source IPs.
**Fix:**
```bash
sudo sysctl net.ipv4.conf.all.rp_filter=0
```
Then remove the sysctl line from `router-zinc.nix` and redeploy.

### Change 2: dnsmasq security options

**Symptom:** DNS queries fail for some domains.
**Cause:** `stop-dns-rebind` blocking legitimate responses with private IPs, or
`domain-needed` blocking short hostnames.
**Fix:**
```bash
sudo systemctl stop dnsmasq
# Temporarily use Cloudflare directly on stud:
# macOS: System Settings > Network > DNS > add 1.1.1.1
```
Then remove the offending dnsmasq option and redeploy.

### Change 3: SSH firewall restriction

**Symptom:** Can't SSH to zinc from WAN (intentional) or from LAN (broken).
**Cause:** Port 22 not allowed on the right interface.
**Fix:** Use Tailscale (`ssh orther@100.100.101.31`) or physical console.
Then revert `openFirewall` change and redeploy.

### Change 4: Tailscale exit node + accept-routes

**Symptom:** Routing table gets extra entries, traffic misrouted (very unlikely).
**Fix:**
```bash
sudo tailscale down
sudo tailscale up --advertise-routes=10.0.0.0/24 --accept-dns=true
```
Then revert the extraUpFlags change and redeploy.

### Change 5: Encrypted DNS (dnscrypt-proxy)

**Symptom:** All DNS fails for LAN devices.
**Cause:** dnscrypt-proxy not running or can't reach upstream.
**Fix (immediate, restores DNS in seconds):**
```bash
# Point dnsmasq back to Cloudflare directly
sudo sh -c 'echo "server=1.1.1.1" >> /etc/dnsmasq.d/emergency.conf'
sudo systemctl restart dnsmasq
```
Then revert the dnscrypt-proxy changes and redeploy.

**This change should use `just deploy-safe` with the 10-minute auto-rollback.**

### Change 6: fail2ban

**Symptom:** Your own IP gets banned.
**Fix:**
```bash
sudo fail2ban-client set sshd unbanip <your-ip>
# Or just:
sudo systemctl stop fail2ban
```

## Key Reminders

- **Zinc has 5 boot generations** — you can always reboot into an older working config
- **`just deploy-safe`** arms a 10-minute auto-rollback — use it for risky changes
- **Tailscale bypasses zinc's firewall** — if LAN SSH breaks, try `ssh orther@100.100.101.31`
- **The LAN switch works independently of zinc** — stud can always reach zinc on 10.0.0.1
  even if WAN/NAT/DNS is broken (ethernet frames don't need routing)
- **Phone hotspot** is your internet lifeline if zinc's WAN is down
