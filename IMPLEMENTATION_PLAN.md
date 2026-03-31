# Service Migration: Pie → Noir

## Overview

Move media management services from pie (2018 Mac Mini) to noir (N6005, 64GB RAM, 1TB NVMe), keeping pie as a dedicated media playback/transcoding box. Add Plex and Jellyfin monitoring.

### Final Service Distribution

| Machine  | Role                          | Services                                                                                                   |
| -------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **pie**  | Media playback & transcoding  | Jellyfin, Plex                                                                                             |
| **noir** | Media management & automation | Sonarr, Radarr, Prowlarr, NZBGet, Jellyseerr, Whisparr, Wizarr, Stash, Tautulli, Jellystat, Home Assistant |

### Service Implementation Strategy

| Service    | NixOS Module        | Implementation                                       |
| ---------- | ------------------- | ---------------------------------------------------- |
| Sonarr     | `services.sonarr`   | Native NixOS service                                 |
| Radarr     | `services.radarr`   | Native NixOS service                                 |
| Prowlarr   | `services.prowlarr` | Native NixOS service                                 |
| NZBGet     | Custom module       | Reuse `services/nzbget.nix` (already standalone)     |
| Tautulli   | `services.tautulli` | Native NixOS service                                 |
| Jellyseerr | Not in nixpkgs      | Podman OCI container                                 |
| Jellystat  | Not in nixpkgs      | Podman OCI container                                 |
| Whisparr   | Not in nixpkgs      | Podman OCI container (reuse `services/whisparr.nix`) |
| Wizarr     | Not in nixpkgs      | Podman OCI container (reuse `services/wizarr.nix`)   |

---

## Stage 1: Native NixOS Services on Noir (Sonarr, Radarr, Prowlarr, Tautulli)

**Goal**: Create standalone service modules and wire them into noir
**Success Criteria**: `nix flake check` passes with new services declared on noir
**Status**: Not Started

### Tasks

1. Create `services/sonarr.nix` — standalone module using `services.sonarr`
   - Enable service, open firewall port 8989
   - Add `nzbget` group to sonarr user (access to NZBGet downloads)
   - Persist `/var/lib/sonarr` via impermanence
   - Depend on NAS mount (`mnt-docker\x2ddata.mount`)
2. Create `services/radarr.nix` — standalone module using `services.radarr`
   - Enable service, open firewall port 7878
   - Add `nzbget` group to radarr user
   - Persist `/var/lib/radarr` via impermanence
   - Depend on NAS mount
3. Create `services/prowlarr.nix` — standalone module using `services.prowlarr`
   - Enable service, open firewall port 9696
   - Persist `/var/lib/prowlarr` via impermanence
4. Create `services/tautulli.nix` — standalone module using `services.tautulli`
   - Enable service, open firewall port 8181
   - Persist `/var/lib/tautulli` via impermanence
5. Import all four new modules in `hosts/noir/default.nix`
6. Run `nix flake check` to validate

---

## Stage 2: NZBGet Migration

**Goal**: Move NZBGet service module from pie to noir
**Success Criteria**: NZBGet module imports cleanly on noir, `nix flake check` passes
**Status**: Not Started

### Tasks

1. Import `services/nzbget.nix` in `hosts/noir/default.nix`
2. Remove NZBGet import from `hosts/pie/default.nix`
3. Verify SOPS secrets (`nzbget/*`) are available to noir (check `.sops.yaml` key access)
4. Run `nix flake check`

---

## Stage 3: Podman Container Services (Jellyseerr, Jellystat, Whisparr, Wizarr)

**Goal**: Create Jellystat and Jellyseerr container modules, move Whisparr and Wizarr to noir
**Success Criteria**: All container services declared on noir, `nix flake check` passes
**Status**: Not Started

### Tasks

1. Create `services/jellyseerr.nix` — Podman OCI container
   - Image: `docker.io/fallenbagel/jellyseerr:latest`
   - Port: 5055
   - Volume: `/var/lib/jellyseerr:/app/config`
   - Persist `/var/lib/jellyseerr` via impermanence
2. Create `services/jellystat.nix` — Podman OCI container
   - Image: `docker.io/cyfershepard/jellystat:latest`
   - Port: 3000 (or 3070 to avoid conflicts)
   - Requires PostgreSQL — evaluate using noir's own Postgres or embedded container
   - Volume: `/var/lib/jellystat:/app/backend/backup-data`
   - Persist via impermanence
3. Move Whisparr import from pie to noir in host configs
   - Update bind mount paths if needed (NZBGet now local on noir)
4. Move Wizarr import from pie to noir in host configs
5. Ensure `/var/lib/containers` persisted on noir (impermanence — per existing memory note)
6. Run `nix flake check`

---

## Stage 4: Noir Host Config Cleanup & Networking

**Goal**: Update noir's firewall, symlinks, and systemd dependencies
**Success Criteria**: All services have correct firewall rules, NAS mount dependencies, and media symlink
**Status**: Not Started

### Tasks

1. Add `/mnt/media` symlink to noir (tmpfiles rule: `L+ /mnt/media - - - - /mnt/docker-data/media`)
2. Verify all service systemd units depend on NAS mount
3. Confirm firewall ports open for all new services:
   - 8989 (Sonarr), 7878 (Radarr), 9696 (Prowlarr)
   - 6789 (NZBGet), 5055 (Jellyseerr), 6969 (Whisparr)
   - 5690 (Wizarr), 8181 (Tautulli), 3000/3070 (Jellystat)
4. Run `nix flake check`

---

## Stage 5: Remove Migrated Services from Pie

**Goal**: Clean pie config to only run Jellyfin + Plex
**Success Criteria**: Pie config has no \*arr services, no NZBGet, no Wizarr/Whisparr; `nix flake check` passes
**Status**: Not Started

### Tasks

1. Remove nixflix Sonarr/Radarr/Prowlarr/Jellyseerr config from `hosts/pie/default.nix`
2. Remove Whisparr, Wizarr, NZBGet imports from `hosts/pie/default.nix`
3. Remove sonarr/radarr `nzbget` group assignments from pie
4. Remove jellyseerr systemd no-op overrides from pie
5. Clean up any orphaned SOPS secret references (nixflix API keys move to noir if needed)
6. Evaluate: remove nixflix input entirely if Jellyfin can run standalone on pie
7. Remove `/var/lib/nixflix` persistence if nixflix removed
8. Run `nix flake check`

---

## Stage 6: Cloudflare Tunnel Route Updates

**Goal**: Update DNS routing so moved services resolve through noir's tunnel
**Success Criteria**: All `*.ryatt.app` subdomains route to correct machine
**Status**: Not Started

### Tasks (Manual — Cloudflare Dashboard)

1. Log into Cloudflare Zero Trust dashboard
2. Navigate to: Access → Tunnels
3. Edit **noir's tunnel** — add new public hostname routes:
   - `sonarr.ryatt.app` → `http://localhost:8989`
   - `radarr.ryatt.app` → `http://localhost:7878`
   - `prowlarr.ryatt.app` → `http://localhost:9696`
   - `seerr.ryatt.app` → `http://localhost:5055`
   - `nzbget.ryatt.app` → `http://localhost:6789`
   - `whisparr.ryatt.app` → `http://localhost:6969`
   - `wizarr.ryatt.app` → `http://localhost:5690`
   - `tautulli.ryatt.app` → `http://localhost:8181`
   - `jellystat.ryatt.app` → `http://localhost:3000` (or 3070)
4. Edit **pie's tunnel** — remove routes for migrated services
   - Keep only: `jellyfin.ryatt.app` → `localhost:8096`, `plex.ryatt.app` → `localhost:32400`
5. Verify each subdomain resolves correctly

---

## Stage 7: Data Migration & Deployment

**Goal**: Deploy to both machines and migrate service data
**Success Criteria**: All services running on correct machines with existing configs preserved
**Status**: Not Started

### Tasks

1. Deploy noir first: `just deploy noir 10.0.0.10`
2. Copy service data from pie to noir via SSH/rsync:
   - `/nix/persist/var/lib/sonarr/` (from nixflix state or `/var/lib/nixflix/sonarr/`)
   - `/nix/persist/var/lib/radarr/`
   - `/nix/persist/var/lib/prowlarr/`
   - `/nix/persist/var/lib/nzbget/` (config only, not downloads)
   - `/nix/persist/var/lib/whisparr3/`
   - `/nix/persist/var/lib/wizarr/`
   - `/nix/persist/var/lib/jellyseerr/` (if exists from nixflix)
3. Deploy pie (cleaned config): `just deploy stud` ... wait, pie. Need to check pie's deploy command.
4. Update Cloudflare tunnel routes (Stage 6)
5. Verify all services accessible via `*.ryatt.app`
6. Update Sonarr/Radarr download client settings to point to localhost NZBGet (was localhost before, stays localhost)
7. Update Prowlarr app connections to point to localhost Sonarr/Radarr (was localhost, stays localhost)

---

## Notes

### Data Path Architecture on Noir

```
/var/lib/nzbget/          ← NZBGet downloads to local NVMe (fast I/O)
/mnt/docker-data/media/   ← NAS media library (NFS from Synology)
/mnt/media                ← Symlink to above
```

Sonarr/Radarr import from NZBGet's local path, then hardlink/move to NAS.

### SOPS Secrets Needed on Noir

- `nzbget/control-username`, `nzbget/control-password`, `nzbget/server-config`
- `nixflix/sonarr-api-key`, `nixflix/radarr-api-key`, `nixflix/prowlarr-api-key` (if used standalone)
- `stash-*` secrets (already there)

### Impermanence Reminder

All `/var/lib/*` service directories AND `/var/lib/containers` (for Podman) must be persisted to `/nix/persist` on noir.
