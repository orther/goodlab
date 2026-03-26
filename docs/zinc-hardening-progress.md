# Zinc Router Hardening — Progress Tracker

**Date:** 2026-03-25
**Branch:** `docs/zinc-tailscale-deploy-address` (will create new branch before changes)
**Recovery guide:** `docs/zinc-recovery-runbook.md`

## Changes

### 1. Kernel sysctl hardening + IPv6 forward-chain lockdown
- **File:** `services/router-zinc.nix`
- **Risk:** ZERO
- **Deploy:** `just deploy zinc 100.100.101.31`
- **Status:** PENDING

**Includes:**
- IPv4 sysctl hardening (SYN cookies, anti-spoofing, martian logging, etc.)
- IPv6 FORWARD chain set to DROP (zinc doesn't route IPv6 traffic today, but the
  chain is currently ACCEPT with no rules — closing this hole)

**Verify:**
```bash
ssh orther@10.0.0.1 "sudo sysctl net.ipv4.tcp_syncookies net.ipv4.conf.all.rp_filter net.ipv4.conf.all.log_martians net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.send_redirects"
# Expected: all 1 except accept_redirects and send_redirects = 0

# Verify IPv6 forward chain is locked down:
ssh orther@10.0.0.1 "sudo ip6tables -L FORWARD -n -v | head -5"
# Expected: policy DROP (or explicit DROP rule)
```

**If broken — immediate fix:**
```bash
ssh orther@10.0.0.1 "sudo sysctl net.ipv4.conf.all.rp_filter=0"
# If IPv6 forward DROP somehow breaks something (very unlikely since no IPv6 routing):
ssh orther@10.0.0.1 "sudo ip6tables -P FORWARD ACCEPT"
```

---

### 2. dnsmasq security hardening
- **File:** `services/router-zinc.nix`
- **Risk:** NEAR-ZERO
- **Deploy:** `just deploy zinc 100.100.101.31`
- **Status:** PENDING

**Verify:**
```bash
# From stud:
dig @10.0.0.1 google.com        # Should resolve
dig @10.0.0.1 -x 10.0.0.1       # Should NOT leak to Cloudflare (NXDOMAIN is fine)
curl -s https://example.com      # Full internet works
```

**If broken — immediate fix:**
```bash
# On stud — temporarily use Cloudflare directly:
# macOS: System Settings > Network > DNS > add 1.1.1.1
# Or from zinc:
ssh orther@10.0.0.1 "sudo systemctl restart dnsmasq"
```

---

### 3. Restrict SSH to LAN + Tailscale
- **File:** `hosts/zinc/default.nix`
- **Risk:** LOW
- **Deploy:** `just deploy zinc 100.100.101.31`
- **Status:** PENDING

**Verify:**
```bash
ssh orther@10.0.0.1 "echo LAN SSH works"           # Should work
ssh orther@100.100.101.31 "echo Tailscale SSH works" # Should work
# Brute force log entries should stop appearing:
ssh orther@10.0.0.1 "sudo journalctl -u sshd --no-pager -n 20"
```

**If broken — immediate fix:**
```bash
# If LAN SSH fails, use Tailscale:
ssh orther@100.100.101.31
# If both fail, physical console on zinc, then:
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system-N-link/bin/switch-to-configuration switch
```

---

### 4. Tailscale exit node + accept-routes
- **File:** `hosts/zinc/default.nix`
- **Risk:** LOW
- **Deploy:** `just deploy zinc 100.100.101.31`
- **Status:** PENDING

**Verify:**
```bash
ssh orther@10.0.0.1 "tailscale status"
# Should show zinc offering exit node
# Check Tailscale admin console to approve exit node
```

**If broken — immediate fix:**
```bash
ssh orther@10.0.0.1 "sudo tailscale down && sudo tailscale up --advertise-routes=10.0.0.0/24 --accept-dns=true"
```

---

### 5. Encrypted upstream DNS (dnscrypt-proxy)
- **File:** `services/router-zinc.nix`
- **Risk:** MEDIUM
- **Deploy:** `just deploy-safe zinc 100.100.101.31` (10-min auto-rollback!)
- **Status:** PENDING

**Verify:**
```bash
# DNS still works:
dig @10.0.0.1 google.com

# dnscrypt-proxy is running:
ssh orther@10.0.0.1 "systemctl status dnscrypt-proxy2"

# No plaintext DNS on WAN (run for ~5 seconds, should see NO port 53 traffic):
ssh orther@10.0.0.1 "sudo timeout 5 tcpdump -i enp1s0 port 53 -c 5 2>&1 || echo 'No plaintext DNS detected - good!'"
```

**If broken — immediate fix:**
```bash
# If deploy-safe: wait 10 minutes for auto-rollback
# If manual fix needed:
ssh orther@10.0.0.1 "sudo systemctl stop dnscrypt-proxy2 && sudo systemctl restart dnsmasq"
# On stud — temporary DNS:
# macOS: System Settings > Network > DNS > add 1.1.1.1
```

---

### 6. fail2ban
- **File:** `hosts/zinc/default.nix`
- **Risk:** LOW
- **Deploy:** `just deploy zinc 100.100.101.31`
- **Status:** PENDING

**Verify:**
```bash
ssh orther@10.0.0.1 "systemctl status fail2ban"
ssh orther@10.0.0.1 "sudo fail2ban-client status sshd"
```

**If broken — immediate fix:**
```bash
# If your IP gets banned:
ssh orther@100.100.101.31 "sudo fail2ban-client set sshd unbanip 10.0.0.30"
# Or just stop it:
ssh orther@100.100.101.31 "sudo systemctl stop fail2ban"
```

---

---

## Future Changes (Separate Session)

### 7. Migrate iptables to nftables
- **Files:** `hosts/zinc/default.nix`, `services/router-zinc.nix`, `services/unifi-zinc.nix`
- **Risk:** HIGH — changes the entire firewall backend
- **Deploy:** `just deploy-safe zinc 100.100.101.31` (mandatory — auto-rollback)
- **Prerequisites:** Physical access to zinc (monitor + keyboard as fallback)
- **Status:** DEFERRED

#### Why

nftables is the modern replacement for iptables on Linux. It offers:
- Atomic rule updates (no brief window of no-rules during reload)
- Better performance (single-pass packet classification)
- Cleaner syntax and rule organization
- The NixOS firewall module has first-class nftables support

#### Critical Compatibility Issues

**Podman/Netavark uses iptables internally.** The NixOS `networking.nftables.enable`
option disables the `ip_tables` kernel module. This will break container port
forwarding (UniFi 8443, 8080, 3478, 10001) unless one of these is done:

1. **Option A (recommended):** Keep nftables + iptables-nft compatibility layer.
   Netavark (podman's network backend) can use `nftables` firewall driver.
   Set in podman config: `firewall_driver = "nftables"`. Verify this is available
   in the nixpkgs version of netavark/aardvark-dns on zinc.

2. **Option B:** Use `networking.nftables.enable = true` but load `ip_tables`
   kernel module explicitly so Netavark's iptables calls work via the compatibility
   translation layer (`iptables-nft` translates iptables commands to nftables).

3. **Option C:** Migrate UniFi containers from podman port-forwarding to
   `networking.nftables.tables` with manual DNAT rules. More control but more
   maintenance.

**Tailscale also injects iptables rules** (`ts-input`, `ts-forward` chains).
Tailscale should work with nftables via the `iptables-nft` compatibility layer,
but this needs testing. Check `tailscale version` — newer versions support nftables
natively.

**fail2ban:** NixOS automatically picks the right firewall package
(`services.fail2ban.packageFirewall` defaults to match your firewall backend).
If you enable nftables, fail2ban will use nftables actions automatically.

**Other hosts with custom iptables rules** (not zinc, but relevant if migrating fleet-wide):
- `services/scrypted.nix` — raw `iptables -A nixos-fw` rules allowing `10.0.10.0/24`
- `services/research-relay/odoo.nix` — raw `iptables -A nixos-fw` allowing Docker bridge `172.17.0.0/16` to PostgreSQL
- `hosts/lildoofy/default.nix` — Tailscale interface-specific port rules
- These use `networking.firewall.extraCommands` which is **incompatible with nftables**.
  Must convert to `networking.firewall.extraInputRules` (nftables syntax).
  **Scope for zinc:** These services don't run on zinc, so zinc migration is self-contained.

#### Implementation Plan

**Phase A: Research (no deploy)**
1. SSH into zinc and check Netavark's firewall driver:
   ```bash
   ssh orther@10.0.0.1 "cat /etc/containers/containers.conf 2>/dev/null; podman info | grep -i firewall"
   ```
2. Check if `iptables-nft` is available:
   ```bash
   ssh orther@10.0.0.1 "which iptables-nft 2>/dev/null || echo 'not found'"
   ```
3. Check Tailscale's nftables support:
   ```bash
   ssh orther@10.0.0.1 "tailscale debug prefs | grep -i nft"
   ```
4. Snapshot current iptables rules for reference:
   ```bash
   ssh orther@10.0.0.1 "sudo iptables-save > /tmp/iptables-backup.txt && cat /tmp/iptables-backup.txt"
   ```

**Phase B: NixOS config changes**
1. Enable nftables:
   ```nix
   # hosts/zinc/default.nix
   networking.nftables.enable = true;
   ```
2. The NixOS firewall module automatically switches to nftables backend when
   `networking.nftables.enable = true`. Existing `networking.firewall.*` and
   `networking.nat.*` options should translate automatically.

3. Handle Podman compatibility (choose based on Phase A findings):
   ```nix
   # If Netavark supports nftables driver:
   virtualisation.podman.defaultNetwork.settings.firewall_driver = "nftables";

   # If not, load iptables compat module:
   boot.kernelModules = ["ip_tables"];
   ```

4. Add forward-chain filtering (nftables-only feature, good for router):
   ```nix
   networking.firewall.filterForward = true;
   networking.firewall.extraForwardRules = ''
     iifname "enp2s0" oifname "enp1s0" accept comment "LAN to WAN"
     iifname "enp1s0" oifname "enp2s0" ct state established,related accept comment "WAN return traffic"
   '';
   ```

**Phase C: Deploy and verify**
1. `just deploy-safe zinc 100.100.101.31` — 10-minute auto-rollback armed
2. Verify checklist:
   ```bash
   # Firewall backend is nftables:
   ssh orther@10.0.0.1 "sudo nft list ruleset | head -30"

   # NAT still works (stud can reach internet):
   curl -s https://example.com

   # Container ports still work:
   curl -sk https://10.0.0.1:8443 | head -5   # UniFi
   curl -s http://10.0.0.1:8123 | head -5     # HA

   # DNS still works:
   dig @10.0.0.1 google.com

   # Tailscale still works:
   ssh orther@100.100.101.31 "tailscale status"
   ```
3. If anything fails, wait for auto-rollback (10 min) or:
   ```bash
   ssh orther@10.0.0.1 "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system"
   ssh orther@10.0.0.1 "sudo /nix/var/nix/profiles/system-N-link/bin/switch-to-configuration switch"
   ```

#### References
- [NixOS Firewall Wiki](https://nixos.wiki/wiki/Firewall)
- [nixos-nftables-firewall docs](https://thelegy.github.io/nixos-nftables-firewall/)
- [Francis Begyn — NixOS Home Router](https://francis.begyn.be/blog/nixos-home-router)
- [NixOS nftables + Docker issue](https://github.com/NixOS/nixpkgs/issues/24318)

---

### 8. Fix Home Assistant SSDP log noise
- **File:** `services/home-assistant-zinc.nix`
- **Risk:** ZERO — cosmetic log fix
- **Deploy:** `just deploy zinc 100.100.101.31`
- **Status:** DEFERRED

#### Problem

Home Assistant logs `[Errno 101] Network is unreachable` for UPnP/SSDP every
~10 minutes. The `default_config` bundle includes the `ssdp` integration, which
sends IPv6 multicast discovery packets. Since zinc's LAN interface (`enp2s0`) has
no global IPv6 address and IPv6 forwarding is enabled (Tailscale sets
`net.ipv6.conf.all.forwarding = 1`), SSDP's IPv6 multicast fails.

#### Root Cause Analysis

The SSDP integration in Home Assistant sends multicast to:
- `239.255.255.250:1900` (IPv4 — works fine)
- `[ff02::c]:1900` / `[ff05::c]:1900` (IPv6 — fails because no routable IPv6)

This is harmless — IPv4 SSDP discovery still works for all LAN devices. The error
is just log noise.

#### Options

**Option A: Suppress at the HA config level (recommended)**

Don't include `ssdp` in `default_config` — instead cherry-pick the components you
actually use. The `default_config` bundle includes ~20 integrations. However, this
is brittle — `default_config` composition changes across HA versions.

A simpler approach: explicitly disable the ssdp integration in HA config:

```nix
services.home-assistant.config = {
  # ... existing config ...

  # Disable SSDP to suppress IPv6 multicast errors.
  # Device discovery still works via mDNS/Avahi (which is configured separately).
  ssdp = {};
};
```

Actually, `default_config` auto-enables `ssdp` and there's no clean way to
disable a sub-integration of `default_config` from Nix. The real options are:

**Option B: Add a link-local IPv6 address to enp2s0**

Let enp2s0 have a link-local IPv6 address so SSDP multicast succeeds:

```nix
networking.interfaces.enp2s0.ipv6.addresses = [{
  address = "fd00::1";
  prefixLength = 64;
}];
```

This gives SSDP a valid IPv6 scope to multicast on. No IPv6 routing is configured,
so this is LAN-only and harmless.

**Option C: Filter the log (least effort)**

Use Home Assistant's `logger` config to suppress the specific component:

```nix
services.home-assistant.config.logger = {
  default = "info";
  logs = {
    "homeassistant.components.ssdp" = "critical";
  };
};
```

This hides the error without fixing the underlying cause.

#### Recommended Approach

**Option C first** (immediate noise fix), then **Option B** if you want clean
IPv6 multicast for future IoT device discovery.

#### Implementation

```nix
# services/home-assistant-zinc.nix — add to config block:
services.home-assistant.config.logger = {
  default = "info";
  logs = {
    "homeassistant.components.ssdp" = "critical";
  };
};
```

#### Verify

```bash
# After deploy, watch HA logs for ~15 minutes:
ssh orther@10.0.0.1 "sudo journalctl -u home-assistant --no-pager -n 50 | grep -i ssdp"
# Should see no more "[Errno 101]" errors

# Confirm HA still discovers devices:
# Check HA web UI > Settings > Devices & Services — existing integrations should still work
```

#### If broken

```bash
# HA won't start (unlikely — logger config is purely additive):
ssh orther@10.0.0.1 "sudo journalctl -u home-assistant --no-pager -n 30"
# Remove the logger config and redeploy
```

---

### 9. Enable IPv6 with DHCPv6-PD and stateful firewall
- **Files:** `services/router-zinc.nix`, `hosts/zinc/default.nix`
- **Risk:** HIGH — firewall misconfiguration exposes all LAN devices directly to internet
- **Deploy:** `just deploy-safe zinc 100.100.101.31` (mandatory — auto-rollback)
- **Prerequisites:** Change 7 (nftables) recommended first — nftables handles dual-stack
  in a single `inet` table, making IPv4+IPv6 firewall management much cleaner
- **Status:** DEFERRED

#### Current State (as of 2026-03-25)

Spectrum IS providing IPv6 to zinc:
- **WAN address:** `2602:107:4e11:1a:6c2d:1b9c:24da:ccca/128` via DHCPv6
- **Delegated prefix:** `2603:8002:8c00:91c9::/64` via DHCPv6-PD (unused)
- **ISP gateway:** `fe80::800:ff:fe00:103` on enp1s0 (learned via RA)
- **ISP DNS (v6):** `2001:1998:f00:1::1`, `2001:1998:f00:2::1`
- **IPv6 forwarding:** Enabled (set by Tailscale)
- **LAN state:** No global IPv6 on enp2s0, no RA daemon, clients failing to get addresses

The delegated `/64` prefix is received by systemd-networkd but never assigned to
the LAN interface or advertised to clients.

#### Why Enable IPv6

- **~5-10% performance improvement** — eliminates NAT overhead for IPv6 destinations
- **35%+ of internet traffic is IPv6** (2025) — growing, not shrinking
- **Apple/gaming compatibility** — Apple TV, PS5, Xbox prefer IPv6 for some features
- **Happy Eyeballs** — devices try IPv6 first; if it doesn't work, 300-2000ms delay
  before falling back to IPv4. Properly enabling removes this penalty.
- **Tailscale** can advertise IPv6 subnet routes to your tailnet
- **HA SSDP fix** — Change 8's IPv6 multicast errors go away naturally

#### Security: The Critical Difference from IPv4

**Without NAT, every device with a global IPv6 address is directly routable from
the internet.** This is NOT a problem IF the firewall is configured correctly:

- Must block all unsolicited inbound traffic on the FORWARD chain (same protection as NAT)
- Must allow NDP (Neighbor Discovery Protocol): ICMPv6 types 133-136
- Must allow established/related return traffic
- Privacy Extensions (RFC 8981) rotate addresses to prevent tracking

**The firewall replaces NAT as the security boundary.** Get it wrong and every
IoT device, printer, and smart lamp is exposed to the internet.

#### Implementation Plan

**Phase A: Configure systemd-networkd for DHCPv6-PD + RA**

```nix
# services/router-zinc.nix — add to networking or create systemd.network config

# WAN interface: request prefix delegation from Spectrum
systemd.network.networks."10-wan" = {
  matchConfig.Name = "enp1s0";
  networkConfig = {
    DHCP = "yes";               # Already doing DHCPv4
    IPv6AcceptRA = true;        # Accept RAs from ISP
  };
  dhcpV6Config = {
    PrefixDelegationHint = "::/64";  # Request /64 (Spectrum's default)
  };
  ipv6PrefixDelegationConfig = {
    Managed = true;
    OtherInformation = true;
  };
};

# LAN interface: send Router Advertisements with delegated prefix
systemd.network.networks."20-lan" = {
  matchConfig.Name = "enp2s0";
  networkConfig = {
    IPv6SendRA = true;          # Send Router Advertisements to LAN
  };
  ipv6SendRAConfig = {
    Managed = false;            # SLAAC (stateless), not DHCPv6 managed
    OtherInformation = true;    # Clients can get DNS via DHCPv6
  };
  # Prefix from DHCPv6-PD is automatically advertised
  ipv6Prefixes = [{
    Prefix = "::/64";           # Placeholder — systemd-networkd fills from PD
    AddressAutoconfiguration = true;
  }];
};
```

**Phase B: IPv6 firewall (CRITICAL)**

With nftables (after Change 7):
```nix
networking.firewall.extraForwardRules = ''
  # IPv6 forwarding: stateful, default deny
  iifname "enp2s0" oifname "enp1s0" accept comment "LAN to WAN (v6)"
  iifname "enp1s0" oifname "enp2s0" ct state established,related accept comment "WAN return (v6)"
  iifname "enp1s0" oifname "enp2s0" drop comment "Block unsolicited inbound (v6)"
'';

# Allow NDP (required for IPv6 to function)
networking.firewall.extraInputRules = ''
  ip6 nexthdr icmpv6 icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept
'';
```

With iptables (if Change 7 not done yet):
```nix
networking.firewall.extraCommands = ''
  # Block unsolicited inbound IPv6 forwarding
  ip6tables -A FORWARD -i enp1s0 -o enp2s0 -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A FORWARD -i enp2s0 -o enp1s0 -j ACCEPT
  ip6tables -A FORWARD -i enp1s0 -o enp2s0 -j DROP

  # Allow NDP
  ip6tables -A INPUT -p icmpv6 --icmpv6-type router-solicitation -j ACCEPT
  ip6tables -A INPUT -p icmpv6 --icmpv6-type router-advertisement -j ACCEPT
  ip6tables -A INPUT -p icmpv6 --icmpv6-type neighbour-solicitation -j ACCEPT
  ip6tables -A INPUT -p icmpv6 --icmpv6-type neighbour-advertisement -j ACCEPT
'';
```

**Phase C: DNS**

Update dnsmasq to also listen on IPv6 and include ISP's v6 DNS servers, or
configure dnscrypt-proxy (Change 5) to handle IPv6 upstream.

**Phase D: Tailscale IPv6 subnet advertisement**

```nix
services.tailscale.extraUpFlags = lib.mkForce [
  "--advertise-routes=10.0.0.0/24,2603:8002:8c00:91c9::/64"
  "--advertise-exit-node"
  "--accept-routes"
  "--accept-dns=true"
];
```

#### Verify

```bash
# LAN client has global IPv6 address:
# On stud: ifconfig en0 | grep inet6   (should show 2603:8002:8c00:91c9::xxxx)

# IPv6 internet works:
ping6 2001:4860:4860::8888    # Google DNS
curl -6 https://ipv6.google.com

# Firewall blocks unsolicited inbound:
# From an external IPv6 host, try to connect to a LAN device — should fail

# SSDP errors gone in HA:
ssh orther@10.0.0.1 "sudo journalctl -u home-assistant --no-pager -n 50 | grep -i ssdp"
```

#### If broken

```bash
# If LAN devices lose connectivity:
ssh orther@10.0.0.1 "sudo ip6tables -P FORWARD ACCEPT"  # Emergency: open forward chain
# Or wait for deploy-safe auto-rollback (10 min)

# If devices get IPv6 but no internet:
ssh orther@10.0.0.1 "ping6 -c 3 2001:4860:4860::8888"   # Can zinc reach v6 internet?
ssh orther@10.0.0.1 "ip -6 route show"                    # Check default route exists
```

#### References
- [systemd-networkd DHCPv6-PD](https://major.io/p/dhcpv6-prefix-delegation-with-systemd-networkd/)
- [ThingLab: NixOS Router IPv6 (2025)](https://thinglab.org/2025/01/nixos_router_ipv6/)
- [Spectrum IPv6 Support](https://www.spectrum.net/support/internet/ipv6)
- [IPv6 Home Firewall Risks](https://ipv6.net/blog/ipv6-home-network-firewall-risks/)
- [Tailscale IPv6](https://tailscale.com/kb/1121/ipv6)

#### Note on Change 8

Enabling IPv6 properly (this change) will likely fix the HA SSDP errors naturally,
since SSDP's IPv6 multicast will succeed once enp2s0 has a global IPv6 address.
If you do Change 9 before Change 8, Change 8 may become unnecessary.

---

## Completion Log

| # | Change | Deployed | Verified | Notes |
|---|--------|----------|----------|-------|
| 1 | Kernel sysctl + IPv6 fwd lockdown | 2026-03-25 | PASS | All sysctls correct, FORWARD policy DROP, internet works |
| 2 | dnsmasq security | 2026-03-25 | PASS | DNS resolves, private reverse blocked, internet works |
| 3 | SSH restriction | 2026-03-25 | PASS | LAN SSH works, Tailscale SSH works, 0 brute force attempts |
| 4 | Tailscale exit node | 2026-03-25 | PASS | Exit node advertised (0.0.0.0/0, ::/0), accept-routes on, approve in admin console |
| 5 | Encrypted DNS | 2026-03-25 | PASS | dnscrypt-proxy active, Cloudflare DoH 19ms RTT, DNS resolves |
| 6 | fail2ban | 2026-03-25 | PASS | Active, sshd jail monitoring, persist dir created |
| 7 | nftables migration | | | DEFERRED — separate session, needs physical access |
| 8 | HA SSDP log fix | 2026-03-25 | PASS | Logger suppresses SSDP errors at critical level |
| 9 | Enable IPv6 (DHCPv6-PD) | | | DEFERRED — do after Change 7 (nftables) |
