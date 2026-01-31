# Pie Media Server Setup Guide: 2018 Mac Mini with NixOS

This guide walks through migrating a 2018 Mac Mini from macOS to NixOS for use as a comprehensive media server with Jellyfin, automated media management (\*arr stack), and hardware transcoding.

## Table of Contents

- [Hardware Overview](#hardware-overview)
- [What's Included](#whats-included)
- [Part 1: Pre-Installation (on macOS)](#part-1-pre-installation-on-macos)
- [Part 2: NixOS Installation](#part-2-nixos-installation)
- [Part 3: SOPS Secrets Setup](#part-3-sops-secrets-setup)
- [Part 4: Post-Installation Configuration](#part-4-post-installation-configuration)
- [Part 5: Jellyfin Client Setup](#part-5-jellyfin-client-setup)
- [Part 6: Family Migration from Plex](#part-6-family-migration-from-plex)
- [Part 7: Disabling Plex After Migration](#part-7-disabling-plex-after-migration)
- [Part 8: Maintenance & Troubleshooting](#part-8-maintenance--troubleshooting)

---

## Hardware Overview

| Component | Specification                              |
| --------- | ------------------------------------------ |
| CPU       | 3.2 GHz 6-Core Intel Core i7 (Coffee Lake) |
| GPU       | Intel UHD Graphics 630 (Quick Sync Video)  |
| RAM       | 32 GB 2667 MHz DDR4                        |
| Security  | Apple T2 chip                              |
| Network   | Gigabit Ethernet + WiFi                    |
| Storage   | Internal NVMe SSD (via T2 controller)      |

### Why This Hardware is Ideal for Media Serving

1. **Intel Quick Sync Video**: The UHD 630 GPU supports hardware encoding/decoding for H.264, HEVC/H.265, VP8, VP9, and MPEG-2 - **free** in Jellyfin (requires Plex Pass with Plex)
2. **6-Core CPU**: Handles multiple simultaneous transcodes if GPU is busy
3. **32GB RAM**: Plenty for media metadata, databases, and caching
4. **Gigabit Ethernet**: Essential for high-bitrate 4K streaming

### T2 Chip Considerations

The T2 security chip requires special handling:

- Controls the internal SSD (requires patched kernel)
- Manages Secure Boot (must be disabled)
- Handles audio codec (requires specific firmware)
- WiFi/Bluetooth require firmware extracted from macOS

---

## What's Included

This configuration provides a media server using **nixflix** for declarative configuration:

### Primary Services

| Service      | Purpose                         | Port  | Status      |
| ------------ | ------------------------------- | ----- | ----------- |
| **Jellyfin** | Media streaming (replaces Plex) | 8096  | **Enabled** |
| Plex         | Media streaming (migration)     | 32400 | Temporary   |

### Future Services (Available but Disabled)

The \*arr services currently run on a separate server. When ready to consolidate, these can be enabled with single-line config changes in nixflix:

| Service    | Purpose                 | Port | Enable With                 |
| ---------- | ----------------------- | ---- | --------------------------- |
| Sonarr     | TV series management    | 8989 | `sonarr.enable = true;`     |
| Radarr     | Movie management        | 7878 | `radarr.enable = true;`     |
| Prowlarr   | Indexer management      | 9696 | `prowlarr.enable = true;`   |
| Jellyseerr | Media request interface | 5055 | `jellyseerr.enable = true;` |

### Why Jellyfin Over Plex?

| Feature                  | Jellyfin   | Plex                            |
| ------------------------ | ---------- | ------------------------------- |
| **Cost**                 | Free       | Free tier + Plex Pass ($120/yr) |
| **Hardware Transcoding** | Free       | Plex Pass required              |
| **Ads in UI**            | None       | Rental/purchase ads             |
| **Open Source**          | Yes        | No                              |
| **Self-Contained**       | 100% local | Requires plex.tv auth           |
| **Data Collection**      | None       | Usage analytics                 |

### Temporary: Plex Migration Service

Plex is included **temporarily** (2-4 weeks) to give family members time to migrate to Jellyfin clients. After migration, Plex will be removed.

---

## Part 1: Pre-Installation (on macOS)

### Step 1.1: Backup Important Data

Before proceeding, backup any data you want to keep from the Mac Mini:

```bash
# Example: Backup to external drive
rsync -avP ~/Documents /Volumes/Backup/mac-mini-backup/
```

### Step 1.2: Backup Plex Server Data (Optional - For Migration Only)

If migrating from an existing Plex setup, you can optionally backup watch history. However, since we're transitioning to Jellyfin, this is less critical.

```bash
# 1. Stop Plex completely
osascript -e 'quit app "Plex Media Server"'
pkill -f "Plex Media Server" 2>/dev/null

# 2. Find and backup the data directory
PLEX_DATA="$HOME/Library/Application Support/Plex Media Server"
tar --exclude='Cache' --exclude='Crash Reports' --exclude='Logs' \
    -cvzf ~/plex-backup.tar.gz \
    -C "$HOME/Library/Application Support" \
    "Plex Media Server"

# 3. Copy to NAS or external drive
cp ~/plex-backup.tar.gz /Volumes/Backup/
```

### Step 1.3: Disable T2 Secure Boot

This is **required** for NixOS installation.

1. **Shut down** the Mac Mini completely
2. **Boot into Recovery Mode**:
   - Power on while holding **Command (⌘) + R**
   - Continue holding until you see the Apple logo or spinning globe
3. **Open Startup Security Utility**:
   - From the menu bar: **Utilities → Startup Security Utility**
   - Enter your admin password if prompted
4. **Configure Security Settings**:
   - **Secure Boot**: Select **"No Security"**
   - **External Boot**: Select **"Allow booting from external media"**
5. **Quit and restart**

### Step 1.4: Download T2-Compatible NixOS ISO

The standard NixOS ISO won't boot on T2 Macs. Use the t2linux project's ISO:

1. **Download the ISO**:
   - Go to: https://github.com/t2linux/nixos-t2-iso/releases
   - Download `t2-iso-minimal-*.iso` (multiple parts if split)
   - If split: `cat t2-iso-minimal-*.iso-part-* > t2-iso-minimal.iso`

2. **Create bootable USB**:

   ```bash
   # Find your USB device (be careful - wrong device will destroy data!)
   diskutil list

   # Unmount the USB (replace diskN with your disk number)
   diskutil unmountDisk /dev/diskN

   # Write the ISO (replace diskN with your disk number)
   sudo dd if=t2-iso-minimal.iso of=/dev/rdiskN bs=4m status=progress

   # Eject when complete
   diskutil eject /dev/diskN
   ```

---

## Part 2: NixOS Installation

### Step 2.1: Boot from USB Installer

1. **Insert USB** into the Mac Mini
2. **Power off** completely (not restart)
3. **Power on** while holding the **Option (⌥)** key
4. **Select** the orange/yellow "EFI Boot" option (the USB)
5. Wait for the NixOS installer to boot

### Step 2.2: Connect to Network

The installer should have Ethernet working automatically. Verify:

```bash
# Check network connectivity
ip addr show
ping -c 3 google.com
```

### Step 2.3: Partition the Internal SSD

The Mac Mini's internal SSD appears as `/dev/nvme0n1` (controlled by the T2 chip).

**Recommended partition layout** (impermanence with tmpfs root):

| Partition | Size      | Type             | Purpose           |
| --------- | --------- | ---------------- | ----------------- |
| nvme0n1p1 | 512MB     | EFI System       | Boot partition    |
| nvme0n1p2 | Remaining | Linux filesystem | /nix (everything) |

```bash
# Open parted
sudo parted /dev/nvme0n1

# Create GPT partition table (WARNING: destroys all data!)
(parted) mklabel gpt

# Create EFI partition (512MB)
(parted) mkpart boot fat32 1MiB 513MiB
(parted) set 1 esp on

# Create main partition (rest of disk)
(parted) mkpart nix ext4 513MiB 100%

# Verify and exit
(parted) print
(parted) quit
```

### Step 2.4: Format Partitions

```bash
# Format EFI partition
sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1

# Format main partition
sudo mkfs.ext4 -L nix /dev/nvme0n1p2
```

### Step 2.5: Mount Partitions

For the impermanence setup (tmpfs root):

```bash
# Create temporary root as tmpfs
sudo mount -t tmpfs -o size=8G,mode=0755 none /mnt

# Create mount points
sudo mkdir -p /mnt/{boot,nix}

# Mount persistent storage
sudo mount /dev/disk/by-label/nix /mnt/nix

# Mount boot partition
sudo mount /dev/disk/by-label/boot /mnt/boot
```

### Step 2.6: Create Persistence Directory Structure

```bash
# Create directories that will persist across reboots
sudo mkdir -p /mnt/nix/persist/{etc/ssh,var/log,var/lib}
sudo mkdir -p /mnt/nix/secret/initrd
```

### Step 2.7: Clone Configuration Repository

```bash
# Install git in the installer environment
nix-env -iA nixos.git

# Clone your goodlab repository
cd /mnt/nix/persist
sudo mkdir -p home/orther/git
cd home/orther/git
sudo git clone https://github.com/orther/goodlab.git
cd goodlab

# IMPORTANT: Checkout the pie configuration branch
# (The pie config is in the feature branch, not main yet)
sudo git checkout feat/add-pie-media-server

# Set ownership (will be corrected after first boot)
sudo chown -R 1000:100 /mnt/nix/persist/home
```

### Step 2.8: Generate Host SSH Keys

These are required for sops-nix to decrypt secrets:

```bash
# Generate SSH host keys in the persistent secret location
sudo ssh-keygen -t ed25519 -f /mnt/nix/secret/initrd/ssh_host_ed25519_key -N ""
sudo ssh-keygen -t rsa -b 4096 -f /mnt/nix/secret/initrd/ssh_host_rsa_key -N ""

# Get the age public key for .sops.yaml
# NOTE: Save this output - you'll need it for Step 3.2
nix-shell -p ssh-to-age --run "ssh-to-age < /mnt/nix/secret/initrd/ssh_host_ed25519_key.pub"
```

**IMPORTANT**: Save the age public key output! It looks like:

```
age1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrs
```

### Step 2.9: Verify Network Configuration (Optional)

The configuration uses systemd-networkd match rules that automatically configure any Ethernet interface, so no manual changes are needed. You can verify your interfaces if curious:

```bash
# Check available network interfaces
ip link show
# The built-in Gigabit Ethernet is typically enp1s0 or similar
# USB adapters show with 'u' in the name (e.g., enp2s0f1u1)
```

No configuration changes needed - the match rules handle any interface name automatically.

### Step 2.10: Install NixOS

The T2 kernel must be compiled from source, which requires significant temporary space. Use persistent storage for the build temp directory to avoid running out of RAM:

```bash
# Create temp directory on persistent storage (required for kernel build)
sudo mkdir -p /mnt/nix/tmp

# Install using the flake configuration
# TMPDIR ensures kernel compilation uses disk instead of RAM
sudo TMPDIR=/mnt/nix/tmp nixos-install --flake /mnt/nix/persist/home/orther/git/goodlab#pie --no-root-passwd

# The installation will take 30-60 minutes (kernel compilation is slow)
```

**If you see "No space left on device" errors:** The build ran out of temp space. Ensure TMPDIR is set correctly and you have at least 20GB free on `/mnt/nix`.

### Step 2.11: First Boot

```bash
# Unmount all partitions
sudo umount -R /mnt

# Reboot
sudo reboot
```

Remove the USB drive when the system starts rebooting.

---

## Part 3: SOPS Secrets Setup

After the first successful boot, configure secrets access.

### Step 3.1: Verify System Boot

After reboot, log in via:

- **Local keyboard/monitor** (if connected)
- **SSH**: `ssh orther@<ip-address>` (find IP via router or `ip addr`)

```bash
# Verify the system is running
uname -a
# Should show Linux with t2linux kernel patches

# Verify GPU is detected
ls -la /dev/dri/
# Should show renderD128
```

### Step 3.2: Get the Age Public Key

On the new pie server:

```bash
# Get the public key from the SSH host key
sudo nix-shell -p ssh-to-age --run "ssh-to-age < /nix/secret/initrd/ssh_host_ed25519_key.pub"
```

Copy this public key (starts with `age1...`).

### Step 3.3: Update .sops.yaml on Another Machine

On a machine that already has access to the secrets (e.g., stud or nblap):

```bash
cd ~/git/goodlab  # or wherever your repo is

# Edit .sops.yaml and replace the placeholder pie key
# Find line: - &pie age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Replace with the actual key from Step 3.2
```

The `.sops.yaml` should look like:

```yaml
keys:
  - &nblap age1pq6uyy9fp43pyxqu9unxjg6nuhuln8psl2lx0exrlpt4ec2s8sgqay5aya
  # ... other keys ...
  - &pie age1YOUR_ACTUAL_PUBLIC_KEY_HERE
creation_rules:
  - path_regex: secrets/[^/]+(\.(yaml|json|env|ini|conf))?$
    key_groups:
      - age:
          - *nblap
          # ... other keys ...
          - *pie
```

### Step 3.4: Re-encrypt Secrets

```bash
# Update the secrets file to include the new key
cd ~/git/goodlab
sops updatekeys secrets/secrets.yaml
```

### Step 3.5: Push Changes and Pull on Pie

```bash
# On the machine where you updated .sops.yaml
git add .sops.yaml secrets/secrets.yaml
git commit -m "feat(pie): add pie host to sops secrets"
git push origin feat/add-pie-media-server
```

Then on the pie server:

```bash
# The repo is persisted at /nix/persist/home/orther/git/goodlab
# After boot, ~/git/goodlab works via impermanence bind mount
cd ~/git/goodlab
git pull origin feat/add-pie-media-server
```

### Step 3.6: Remove Temporary Password and Rebuild

Now that SOPS is configured, remove the temporary initial password:

```bash
# On another machine (stud/nblap), edit the pie configuration
# Remove this line from hosts/pie/default.nix:
#   users.users.orther.initialPassword = "changeme";

# Commit and push
git add hosts/pie/default.nix
git commit -m "fix(pie): remove temporary initial password now that SOPS works"
git push origin feat/add-pie-media-server
```

Then on the pie server:

```bash
cd ~/git/goodlab
git pull origin feat/add-pie-media-server

# Rebuild to apply SOPS-managed password
sudo nixos-rebuild switch --flake ~/git/goodlab#pie
```

After this rebuild, your password will be managed by SOPS secrets.

---

## Part 4: Post-Installation Configuration

### Step 4.1: Verify Hardware Transcoding

Check that the Intel GPU is properly configured:

```bash
# Check GPU device nodes exist
ls -la /dev/dri/
# Expected output:
# crw-rw---- 1 root video 226,   0 ... card0
# crw-rw---- 1 root render 226, 128 ... renderD128

# Verify VA-API is working
vainfo
# Should show "libva info: VA-API version: 1.x"
# And list supported profiles like VAProfileH264Main, VAProfileHEVCMain, etc.

# Check that service users have GPU access
groups jellyfin
groups plex
# Both should include: video render
```

### Step 4.2: Verify NAS Mount

```bash
# Check NAS mount is working
ls /mnt/media
# Should show your media folders (movies, tv, etc.)

# Check media symlink
ls -la /mnt/media
# Should be a symlink to /mnt/docker-data/media
```

### Step 4.3: Access Jellyfin

**Primary media server - all family members should use Jellyfin**

1. Open browser to: `http://pie:8096` or `http://<ip>:8096`
2. Complete the initial setup wizard:
   - Set language
   - Create admin account
   - **Add media libraries**:
     - Movies: `/mnt/media/movies`
     - TV Shows: `/mnt/media/tv`
   - Configure remote access (optional)
3. Go to **Dashboard → Playback → Transcoding**:
   - Enable **Hardware acceleration**: **VAAPI**
   - Hardware acceleration device: `/dev/dri/renderD128`
   - Enable hardware encoding

### Step 4.4: Enable \*arr Services (Optional/Future)

The \*arr services are currently disabled since they run on a separate server. When ready to consolidate, edit `hosts/pie/default.nix` and uncomment the relevant services in the nixflix block:

```nix
nixflix = {
  # ... existing config ...

  # Uncomment to enable:
  # sonarr.enable = true;
  # radarr.enable = true;
  # prowlarr.enable = true;
  # jellyseerr.enable = true;
};
```

Then rebuild: `sudo nixos-rebuild switch --flake .#pie`

**Recommended setup order when enabling:**

1. **Prowlarr**: Add your indexers (Usenet or torrent)
2. **Radarr/Sonarr**: Configure download clients and root folders
3. **Jellyseerr**: Connect to Radarr, Sonarr, and Jellyfin

### Step 4.5: Temporary Plex Access

During the migration period, Plex is available at:

- URL: `http://pie:32400/web`
- Claim the server with your Plex account
- Enable hardware transcoding (Settings → Transcoder)
- Add libraries: `/mnt/media/movies`, `/mnt/media/tv`

---

## Part 5: Jellyfin Client Setup

### Available Clients

| Platform    | Recommended Client       | Notes              |
| ----------- | ------------------------ | ------------------ |
| iOS/iPadOS  | Swiftfin (App Store)     | Free, native UI    |
| Android     | Jellyfin (Play Store)    | Official client    |
| Apple TV    | Swiftfin                 | Free, native UI    |
| Android TV  | Jellyfin for Android TV  | Official client    |
| Fire TV     | Jellyfin for Android TV  | Sideload or store  |
| Web Browser | Built-in web UI          | `http://pie:8096`  |
| Windows     | Jellyfin Media Player    | Native desktop app |
| macOS       | Jellyfin Media Player    | Native desktop app |
| Roku        | Jellyfin (Channel Store) | Official channel   |

### Quick Start for Family

1. **Download Swiftfin** (iOS/tvOS) or **Jellyfin** (Android)
2. **Add server**: `http://pie:8096` or `http://<pie-ip>:8096`
3. **Create account**: Admin creates accounts in Jellyfin Dashboard
4. **Sign in** and start watching!

### Requesting New Content

Family members can request movies and TV shows through **Jellyseerr**:

1. Go to: `http://pie:5055`
2. Sign in with Jellyfin credentials
3. Search for content
4. Click "Request" - it's automatically sent to Radarr/Sonarr

---

## Part 6: Family Migration from Plex

### Migration Timeline

| Week | Goal                                       |
| ---- | ------------------------------------------ |
| 1    | Set up Jellyfin, install clients           |
| 2    | Family tests Jellyfin alongside Plex       |
| 3    | Transition "Continue Watching" to Jellyfin |
| 4    | Disable Plex                               |

### For Family Members

**What you'll notice that's better:**

- No rental/purchase ads in the interface
- Faster transcoding startup (no server communication delay)
- Same high-quality streaming

**What's the same:**

- Same media libraries (movies, TV shows)
- Hardware transcoding for any device
- Remote streaming (via Tailscale)

**What's different:**

- Different app (Swiftfin instead of Plex)
- Different web URL (`:8096` instead of `:32400`)
- No "Plex Pass" features to miss - Jellyfin has them all free

### Tracking Migration Progress

Create a checklist for each family member:

- [ ] Jellyfin client installed
- [ ] Can browse and play content
- [ ] Knows how to use Jellyseerr for requests
- [ ] Has migrated from "Continue Watching" on Plex
- [ ] Confirmed ready to remove Plex

---

## Part 7: Disabling Plex After Migration

Once all family members have migrated, remove Plex:

### Step 7.1: Confirm Everyone Has Migrated

```bash
# Check Plex hasn't been used recently (on pie server)
# Look at Plex dashboard for recent activity
# Or check logs:
journalctl -u plex --since "7 days ago" | grep -i "stream\|play"
```

### Step 7.2: Update Configuration

Edit `hosts/pie/default.nix` and make the following changes:

1. **Remove the plex.nix import:**

```nix
imports = [
  # ... other imports ...

  # REMOVE THIS LINE:
  # ./../../services/plex.nix
];
```

2. **Remove plex from mediaUsers:**

```nix
nixflix = {
  # ...
  mediaUsers = ["orther"];  # Remove "plex"
};
```

3. **Remove plex user GPU access:**

```nix
# REMOVE THIS LINE:
# users.users.plex.extraGroups = ["video" "render"];
```

### Step 7.3: Rebuild System

```bash
# On pie server
cd ~/git/goodlab
sudo nixos-rebuild switch --flake .#pie
```

### Step 7.4: Clean Up Plex Data (Optional)

```bash
# After confirming Plex is disabled
sudo rm -rf /nix/persist/var/lib/plex
```

### Step 7.5: Commit Changes

```bash
cd ~/git/goodlab
git add hosts/pie/default.nix
git commit -m "feat(pie): remove temporary Plex migration service"
git push
```

---

## Part 8: Maintenance & Troubleshooting

### Updating the System

```bash
# Pull latest configuration changes
cd ~/git/goodlab
git pull

# Update flake inputs (optional, for package updates)
nix flake update

# Rebuild the system
sudo nixos-rebuild switch --flake .#pie
```

### Common Issues

#### 1. Jellyfin Hardware Transcoding Not Working

**Symptom**: Transcoding is slow or uses CPU

**Diagnosis**:

```bash
# Check GPU access
ls -la /dev/dri/renderD128
groups jellyfin

# Check VA-API
vainfo

# Check Jellyfin logs
journalctl -u jellyfin -f
```

**Fixes**:

- Verify VAAPI is selected in Dashboard → Playback → Transcoding
- Ensure `/dev/dri/renderD128` is the hardware device path
- Rebuild: `sudo nixos-rebuild switch --flake .#pie`

#### 2. NAS Mount Failures

**Symptom**: `/mnt/media` is empty or mount fails

**Diagnosis**:

```bash
# Check mount status
systemctl status mnt-docker\\x2ddata.mount

# Check if NAS is reachable
ping 10.4.0.50

# Try manual mount
sudo mount -t nfs -o nfsvers=4.1 10.4.0.50:/volume1/docker-data /mnt/test
```

#### 3. Jellyfin Can't Find Media

**Symptom**: Media libraries are empty or missing

**Fixes**:

- Verify NAS mount: `ls /mnt/media`
- Check symlink exists: `ls -la /mnt/media` (should point to `/mnt/docker-data/media`)
- Verify service has media group: `groups jellyfin`

### Log Locations

| Log              | Command                                   |
| ---------------- | ----------------------------------------- |
| System journal   | `journalctl -b`                           |
| Jellyfin         | `journalctl -u jellyfin -f`               |
| Plex (temporary) | `journalctl -u plex -f`                   |
| NAS Mount        | `journalctl -u mnt-docker\\x2ddata.mount` |

### Useful Commands Reference

```bash
# System status
systemctl status jellyfin plex

# Rebuild system
sudo nixos-rebuild switch --flake ~/git/goodlab#pie

# Check hardware acceleration
vainfo
intel_gpu_top  # During playback

# Network diagnostics
ip addr show
ping 10.4.0.50  # NAS
mount | grep nfs

# Service management
sudo systemctl restart jellyfin
```

---

## Appendix: File Reference

### Configuration Files

| File                                      | Purpose                    |
| ----------------------------------------- | -------------------------- |
| `hosts/pie/default.nix`          | Main host configuration    |
| `hosts/pie/hardware-configuration.nix` | Hardware-specific settings |
| `services/plex.nix`                       | Temporary Plex service     |
| `services/nas.nix`                        | NAS mount configuration    |
| `modules/nixos/base.nix`                  | Common NixOS settings      |
| `.sops.yaml`                              | Secrets encryption keys    |

### Key Directories on Pie Server

| Path               | Purpose                              |
| ------------------ | ------------------------------------ |
| `/nix/persist`     | Persistent storage (survives reboot) |
| `/nix/secret`      | SSH keys for sops-nix                |
| `/var/lib/nixflix` | Nixflix service state                |
| `/var/lib/plex`    | Plex database (temporary)            |
| `/mnt/media`       | NAS media mount point                |
| `~/git/goodlab`    | NixOS configuration repo             |

---

## Quick Start Checklist

### Pre-Installation (macOS)

- [ ] Backup Mac Mini data
- [ ] Disable T2 Secure Boot
- [ ] Download and flash t2linux NixOS ISO

### Installation

- [ ] Boot from USB and partition disk
- [ ] Mount filesystems and generate config
- [ ] Clone goodlab repo and generate SSH keys
- [ ] Install NixOS with `nixos-install --flake .#pie`
- [ ] Boot into NixOS and verify login

### Configuration

- [ ] Update .sops.yaml with pie age key
- [ ] Re-encrypt secrets and rebuild

### Service Setup

- [ ] Access Jellyfin and complete setup wizard
- [ ] Enable VAAPI hardware transcoding in Jellyfin
- [ ] (Optional) Configure Plex for migration period
- [ ] (Future) Enable \*arr services when ready to consolidate

### Family Migration

- [ ] Install Jellyfin clients on all devices
- [ ] Create Jellyfin accounts for family
- [ ] Test playback on all devices
- [ ] Train family on Jellyseerr requests
- [ ] Monitor for 2-4 weeks
- [ ] Disable Plex when ready
