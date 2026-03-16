# Zinc Router Prep Plan

Preparing zinc to replace the Spectrum router. Work is split into sequential phases —
check off items as they are completed.

---

## Phase 1: Pre-Router Prep (this PR — `feat/zinc-pre-router-prep`)

### Step 1.1 — LUKS Auto-Unlock via Keyfile in Initrd

**Why keyfile instead of TPM2:** TPM2 requires `boot.initrd.systemd.enable = true` which
conflicts with the existing `remote-unlock.nix` (classic busybox initrd). Keyfile approach:
- Works with existing classic initrd — no initrd type change needed
- Passphrase always works as fallback — cannot brick the machine

**Imperative step (run once on zinc before deploying):**

```bash
ssh zinc "sudo mkdir -p /nix/persist/etc/secrets && \
  sudo dd if=/dev/urandom of=/nix/persist/etc/secrets/luks-keyfile bs=4096 count=1 && \
  sudo chmod 000 /nix/persist/etc/secrets/luks-keyfile && \
  sudo cryptsetup luksAddKey /dev/sda2 /nix/persist/etc/secrets/luks-keyfile"
# Will prompt for existing LUKS passphrase to authorize the new key slot
```

**NixOS config changes:**

- [ ] `hosts/zinc/hardware-configuration.nix` — add inside `boot.initrd` block:
  ```nix
  secrets = {
    "/crypto_keyfile.bin" = "/nix/persist/etc/secrets/luks-keyfile";
  };
  luks.devices."cryptroot".keyFile = "/crypto_keyfile.bin";
  ```
- [ ] `hosts/zinc/default.nix` — remove `inputs.self.nixosModules."remote-unlock"` import
- [ ] Verify no other host imports `remote-unlock` before removing/leaving the module

**Verification:**
- [ ] Run imperative step above (ssh to zinc)
- [ ] `just deploy zinc 192.168.1.158`
- [ ] `ssh zinc "sudo reboot"`
- [ ] After ~30s: `ssh zinc "uptime"` — confirms auto-unlock worked (no manual password typed)

---

### Step 1.2 — Safe Deploy Recipes for Networking Changes

Add to `justfile`:

- [ ] `deploy-safe machine ip` — arms a 10-min auto-rollback timer, then deploys
- [ ] `cancel-rollback ip` — manually cancels rollback timer when you need >10 min to verify

```just
# Use for: firewall, routing, network interface, NAT changes.
# Arms a 10-minute auto-rollback. If SSH breaks, previous generation auto-restores.
deploy-safe machine ip:
  #!/usr/bin/env sh
  set -euo pipefail
  echo "Arming 10-min rollback timer..."
  ssh "orther@{{ip}}" "sudo systemd-run --on-active=600 --unit=nixos-rollback \
    /run/current-system/sw/bin/nixos-rebuild switch --rollback"
  just deploy {{machine}} {{ip}} || {
    echo "Deploy failed — cancelling rollback timer"
    ssh "orther@{{ip}}" "sudo systemctl stop nixos-rollback.service 2>/dev/null; true"
    exit 1
  }
  ssh "orther@{{ip}}" "sudo systemctl stop nixos-rollback.service 2>/dev/null; true"
  echo "Deploy confirmed. Rollback timer cancelled."

# Use for: manually cancelling the rollback timer when you need >10 min to verify.
cancel-rollback ip:
  ssh "orther@{{ip}}" "sudo systemctl stop nixos-rollback.service 2>/dev/null; \
    sudo systemctl stop nixos-rollback.timer 2>/dev/null; true"
  echo "Rollback timer cancelled for {{ip}}."
```

**Verification:**
- [ ] `just --list` shows new recipes
- [ ] `just cancel-rollback 192.168.1.158` runs without error (timer not running = harmless)

---

### Step 1.3 — Document Deploy Commands in CLAUDE.md

Add under "Essential Commands > Deployment" in `goodlab/CLAUDE.md`:

- [ ] Add deploy command decision table:

```markdown
#### Choosing the Right Deploy Command

| Command | When to Use |
|---------|-------------|
| `just deploy <host> [ip]` | All normal changes: services, config, packages. **Default choice.** |
| `just deploy-safe <host> <ip>` | **Required** for: firewall rules, routing config, network interfaces, NAT. Arms a 10-minute auto-rollback that restores the previous generation if SSH is lost. |
| `just cancel-rollback <ip>` | Use after `deploy-safe` if you need more than 10 minutes to verify before the timer fires. |
```

---

## Phase 2: UniFi Gear Reset + Adoption (Manual — physical access required)

Do this AFTER Phase 1 PR is deployed and verified. The UniFi controller is already running
on zinc at `https://192.168.1.158:8443`.

- [ ] Factory reset each device (hold reset ~10s until LED cycles):
  - [ ] USW 24 PoE (condo — core switch)
  - [ ] USW Lite 16 PoE (garage — secondary switch)
  - [ ] U6 LR (condo — anchor AP + 6GHz backhaul)
  - [ ] U6 Lite (condo — client AP)
  - [ ] U6 Pro (garage — bridge AP)
- [ ] For devices that don't auto-discover, SSH in and set inform URL:
  ```
  set-inform http://192.168.1.158:8080/inform
  ```
- [ ] Adopt all devices in UniFi Network Application (`https://192.168.1.158:8443`)
- [ ] Configure SSIDs and network layout using the 10.0.0.x plan (Phase 4)
- [ ] Pre-configure all MAC→IP DHCP reservations (see Phase 4)
- [ ] Re-establish U6 LR ↔ U6 Pro 6GHz wireless bridge (garage backhaul)

**Note:** Inform URL changes to `http://10.0.0.1:8080/inform` after router cutover.
UniFi devices will be auto-redirected once controller config is updated.

---

## Phase 3: Router Config (separate PR — `feat/zinc-router`)

### Interface Assignment

| Port | Interface | MAC suffix | Role |
|------|-----------|------------|------|
| Port 1 | `enp1s0` | `c6:7d` | WAN (Netgear CM1100 modem) |
| Port 2 | `enp2s0` | `c6:7e` | LAN → USW 24 PoE |
| Port 3 | `eno1` | `c6:7f` | LAN (spare / future) |
| Port 4 | `enp4s0` | `c6:80` | Management (`192.168.254.0/24`) |

- [ ] `systemd.network.links` — pin interface names to MACs
- [ ] `networking.nat` — NAT for LAN → WAN
- [ ] `services.kea.dhcp4` — DHCP server for 10.0.0.0/24
- [ ] `services.dnsmasq` — DNS resolver
- [ ] Firewall: nftables, locked down (only allow services we want)
- [ ] No IPv6 (not needed)
- [ ] Update `home-assistant-zinc.nix`:
  ```nix
  internal_url = "http://10.0.0.1:8123";  # was 192.168.1.158:8123
  ```
- [ ] Update UniFi inform URL to `http://10.0.0.1:8080/inform`

### Modem Swap
- [ ] Replace Spectrum modem with Netgear CM1100 (DOCSIS 3.1, 2.5GbE)
- [ ] CM1100 → zinc `enp1s0` (WAN, DHCP from Spectrum)
- [ ] If Spectrum has old router MAC locked: call to release or wait ~24h

---

## Phase 4: Network Address Space — 10.0.0.0/24

### Allocation Map

| Range | Type | Purpose |
|---|---|---|
| `10.0.0.1` | Static | Gateway (zinc) |
| `10.0.0.2–9` | Static | Network infrastructure |
| `10.0.0.10–29` | Static | Servers + NAS |
| `10.0.0.30–49` | Static | Workstations — wired |
| `10.0.0.50–69` | Static | Workstations — wifi |
| `10.0.0.70–99` | Reserved static | Future computers |
| `10.0.0.100–119` | DHCP reservation | Personal mobile |
| `10.0.0.120–129` | DHCP reservation | Printers + peripherals |
| `10.0.0.130–159` | DHCP reservation | IoT + Home Automation |
| `10.0.0.160–179` | DHCP reservation | Streaming + entertainment |
| `10.0.0.180–199` | Reserved DHCP | Future |
| `10.0.0.200–254` | Dynamic DHCP | Guests / unknown |

### Specific Assignments

#### Gateway
| IP | Host | Notes |
|---|---|---|
| `10.0.0.1` | zinc | Router · HA (`:8123`) · UniFi (`:8443`) |

#### Network Infrastructure (`10.0.0.2–9`) — configured in UniFi
| IP | Device | Location |
|---|---|---|
| `10.0.0.2` | USW 24 PoE | Condo — core switch |
| `10.0.0.3` | USW Lite 16 PoE | Garage — secondary switch |
| `10.0.0.4` | U6 LR | Condo — anchor AP + 6GHz backhaul |
| `10.0.0.5` | U6 Lite | Condo — client AP |
| `10.0.0.6` | U6 Pro | Garage — bridge AP |
| `10.0.0.7–9` | — | Reserved |

#### Servers + NAS (`10.0.0.10–29`) — static
| IP | Host | Notes |
|---|---|---|
| `10.0.0.10` | noir | NixOS miniPC (moving from old house) |
| `10.0.0.11` | arson | NUC miniPC (moving from old house) |
| `10.0.0.12` | nas | NAS — garage, wired to USW Lite 16 |
| `10.0.0.13` | pie | NixOS Mac Mini — garage, media/Jellyfin |
| `10.0.0.14–29` | — | Reserved |

#### Workstations — Wired (`10.0.0.30–49`) — static
| IP | Host | Notes |
|---|---|---|
| `10.0.0.30` | stud-eth | M-series MacBook, ethernet adapter |
| `10.0.0.31` | mair-eth | Intel MacBook, ethernet |
| `10.0.0.32–49` | — | Reserved |

#### Workstations — WiFi (`10.0.0.50–69`) — static
| IP | Host | Notes |
|---|---|---|
| `10.0.0.50` | stud-wifi | M-series MacBook, wifi |
| `10.0.0.51` | mair-wifi | Intel MacBook, wifi |
| `10.0.0.52` | nblap-wifi | Work MacBook, wifi |
| `10.0.0.53–69` | — | Reserved |

#### Personal Mobile (`10.0.0.100–119`) — DHCP reservation by MAC
| IP | Device | Notes |
|---|---|---|
| `10.0.0.100` | brandon-iphone | iPhone, wifi |
| `10.0.0.101` | ryatt-tablet | Tablet, wifi |
| `10.0.0.102–119` | — | Reserved |

#### Printers + Peripherals (`10.0.0.120–129`) — DHCP reservation
| IP | Device | Notes |
|---|---|---|
| `10.0.0.120` | brother-printer | Brother printer |
| `10.0.0.121–129` | — | Reserved |

#### IoT + Home Automation (`10.0.0.130–159`) — DHCP reservation
| IP | Device | Notes |
|---|---|---|
| `10.0.0.130` | unifi-led | UniFi LED panel |
| `10.0.0.131–139` | esp32-* | ESP32-S3 presence sensors |
| `10.0.0.140` | lutron-caseta | Lutron Caseta smart bridge |
| `10.0.0.141–149` | ha-hub-* | Other HA hubs/bridges |
| `10.0.0.150–159` | — | Reserved IoT |

#### Streaming + Entertainment (`10.0.0.160–179`) — DHCP reservation
| IP | Device | Notes |
|---|---|---|
| `10.0.0.160–164` | chromecast-* | Multiple Chromecasts |
| `10.0.0.165–179` | — | Reserved (Apple TV, etc.) |

#### Dynamic Pool (`10.0.0.200–254`)
Guests, new devices, anything without a MAC reservation.
