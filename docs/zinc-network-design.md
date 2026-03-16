# Zinc Router — Network Address Design

## Topology

```
ISP (Spectrum Cable)
  └─ Modem (Spectrum temp → Netgear CM1100, DOCSIS 3.1, 2.5GbE)
       └─ zinc enp1s0 (WAN — DHCP from Spectrum)
            ↓ NAT
       zinc enp2s0 (LAN) → USW 24 PoE (core switch, condo)
                                ├─ U6 Pro   (Kitchen AP — wired PoE)
                                └─ U6 Lite  (Master Bedroom AP — wired PoE)
       zinc enp4s0 (Mgmt) → 192.168.254.0/24
```

**Future garage phase** (requires dedicated wireless bridge — not yet purchased):
- Bridge: condo USW 24 ↔ garage USW Lite 16 PoE (Layer 2)
- NAS + pie (Jellyfin Mac Mini) move to garage behind USW Lite 16

## Interface Assignment

| Port | Interface | MAC suffix | Role |
|------|-----------|-----------|------|
| Port 1 | `enp1s0` | `c6:7d` | WAN (CM1100 modem) |
| Port 2 | `enp2s0` | `c6:7e` | LAN → USW 24 PoE |
| Port 3 | `eno1` | `c6:7f` | LAN (spare / future) |
| Port 4 | `enp4s0` | `c6:80` | Management (`192.168.254.0/24`) |

Interfaces are pinned to MACs via `systemd.network.links`.

## 10.0.0.0/24 Allocation Map

| Range | Type | Purpose |
|-------|------|---------|
| `10.0.0.1` | Static | Gateway (zinc) |
| `10.0.0.2–9` | Static | Network infrastructure (switches, APs) |
| `10.0.0.10–29` | Static | Servers + NAS |
| `10.0.0.30–49` | Static | Workstations — wired ethernet |
| `10.0.0.50–69` | Static | Workstations — wifi |
| `10.0.0.70–99` | Reserved static | Future computers |
| `10.0.0.100–119` | DHCP reservation | Personal mobile (phones, tablets) |
| `10.0.0.120–129` | DHCP reservation | Printers + peripherals |
| `10.0.0.130–159` | DHCP reservation | IoT + Home Automation |
| `10.0.0.160–179` | DHCP reservation | Streaming + entertainment |
| `10.0.0.180–199` | Reserved DHCP | Future reservations |
| `10.0.0.200–254` | Dynamic DHCP | Unknown / temporary / guests |

## Specific Assignments

### Gateway

| IP | Host | Notes |
|----|------|-------|
| `10.0.0.1` | zinc | Router, HA (`:8123`), UniFi (`:8443`) |

### Network Infrastructure (`10.0.0.2–9`) — static, configured in UniFi

| IP | Device | Location | Status |
|----|--------|----------|--------|
| `10.0.0.2` | USW 24 PoE | Condo — core switch | Active |
| `10.0.0.3` | USW Lite 16 PoE | Reserved — garage (future) | Not deployed |
| `10.0.0.4` | U6 Pro | Condo — Kitchen AP (wired PoE) | Active |
| `10.0.0.5` | U6 Lite | Condo — Master Bedroom AP (wired PoE) | Active |
| `10.0.0.6–9` | — | Reserved | — |

### Servers + NAS (`10.0.0.10–29`) — static

| IP | Host | Notes | Status |
|----|------|-------|--------|
| `10.0.0.10` | noir | NixOS miniPC (moving from old house) | Pending |
| `10.0.0.11` | arson | NUC miniPC (moving from old house) | Pending |
| `10.0.0.12` | nas | NAS — will go in garage after bridge | Not deployed |
| `10.0.0.13` | pie | NixOS Mac Mini — Jellyfin, garage phase | Not deployed |
| `10.0.0.14–29` | — | Reserved | — |

### Workstations — Wired (`10.0.0.30–49`) — static

| IP | Host | Notes |
|----|------|-------|
| `10.0.0.30` | stud-eth | This MacBook, ethernet adapter |
| `10.0.0.31` | mair-eth | Intel MacBook, ethernet |
| `10.0.0.32–49` | — | Reserved |

### Workstations — WiFi (`10.0.0.50–69`) — static

| IP | Host | Notes |
|----|------|-------|
| `10.0.0.50` | stud-wifi | This MacBook, wifi |
| `10.0.0.51` | mair-wifi | Intel MacBook, wifi |
| `10.0.0.52` | nblap-wifi | Work MacBook, wifi |
| `10.0.0.53–69` | — | Reserved |

### Personal Mobile (`10.0.0.100–119`) — DHCP reservation by MAC

| IP | Device | Notes |
|----|--------|-------|
| `10.0.0.100` | brandon-iphone | Brandon's iPhone, wifi |
| `10.0.0.101` | ryatt-tablet | Ryatt's tablet, wifi |
| `10.0.0.102–119` | — | Reserved |

### Printers + Peripherals (`10.0.0.120–129`) — DHCP reservation

| IP | Device | Notes |
|----|--------|-------|
| `10.0.0.120` | brother-printer | Brother printer |
| `10.0.0.121–129` | — | Reserved |

### IoT + Home Automation (`10.0.0.130–159`) — DHCP reservation

| IP | Device | Notes |
|----|--------|-------|
| `10.0.0.130` | unifi-led | UniFi LED panel |
| `10.0.0.131–139` | esp32-* | ESP32-S3 presence sensors (multiple) |
| `10.0.0.140` | lutron-caseta | Lutron Caseta smart bridge |
| `10.0.0.141–149` | ha-hub-* | Other HA hubs/bridges (fill in during setup) |
| `10.0.0.150–159` | — | Reserved IoT |

### Streaming + Entertainment (`10.0.0.160–179`) — DHCP reservation

| IP | Device | Notes |
|----|--------|-------|
| `10.0.0.160–164` | chromecast-* | Multiple Chromecasts |
| `10.0.0.165–179` | — | Reserved (Apple TV, etc.) |

### Dynamic Pool (`10.0.0.200–254`)

Guests, new devices, anything without a MAC reservation.

## Modem Swap Note

Replacing Spectrum modem with **Netgear CM1100** (DOCSIS 3.1, 2.5GbE WAN port).
CM1100 connects directly to zinc's `enp1s0`. Spectrum uses DHCP on WAN — no PPPoE.
If Spectrum has the old router's MAC locked, call to release it or wait ~24h for DHCP
lease to expire.

## Home Assistant Config Update (when network switches)

`services/home-assistant-zinc.nix` will need updating:
```nix
internal_url = "http://10.0.0.1:8123";  # currently 192.168.1.158:8123
```

## UniFi Controller URL Update (after router cutover)

Inform URL changes from `http://192.168.1.158:8080/inform` to `http://10.0.0.1:8080/inform`.

## Pre-Cutover: UniFi Gear Reset + Local Controller Adoption

Do this AFTER LUKS/deploy-safe PR is deployed, BEFORE router config PR.
Local UniFi controller runs on zinc at `https://192.168.1.158:8443`.

1. **Factory reset each device** — hold reset ~10s until LED cycles:
   - USW 24 PoE
   - U6 Pro (Kitchen)
   - U6 Lite (Master Bedroom)

2. **Set inform URL** for devices that don't auto-discover zinc:
   ```
   set-inform http://192.168.1.158:8080/inform
   ```

3. **Adopt in UniFi Network Application** at `https://192.168.1.158:8443`

4. **Pre-configure DHCP reservations** — enter all MAC→IP reservations before
   router cutover so devices get correct IPs immediately after the switch.
