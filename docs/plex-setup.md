# Plex Server Setup Guide: 2018 Mac Mini with NixOS

This guide walks through migrating a 2018 Mac Mini from macOS to NixOS for use as a dedicated Plex media server with Intel Quick Sync hardware transcoding.

## Table of Contents

- [Hardware Overview](#hardware-overview)
- [Part 1: Pre-Installation (on macOS)](#part-1-pre-installation-on-macos)
- [Part 2: NixOS Installation](#part-2-nixos-installation)
- [Part 3: SOPS Secrets Setup](#part-3-sops-secrets-setup)
- [Part 4: Plex Data Migration (Optional)](#part-4-plex-data-migration-optional)
- [Part 5: Post-Installation Configuration](#part-5-post-installation-configuration)
- [Part 6: Maintenance & Troubleshooting](#part-6-maintenance--troubleshooting)

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

### Why This Hardware is Ideal for Plex

1. **Intel Quick Sync Video**: The UHD 630 GPU supports hardware encoding/decoding for H.264, HEVC/H.265, VP8, VP9, and MPEG-2
2. **6-Core CPU**: Handles multiple simultaneous transcodes if GPU is busy
3. **32GB RAM**: Plenty for Plex metadata and caching
4. **Gigabit Ethernet**: Essential for high-bitrate 4K streaming

### T2 Chip Considerations

The T2 security chip requires special handling:

- Controls the internal SSD (requires patched kernel)
- Manages Secure Boot (must be disabled)
- Handles audio codec (requires specific firmware)
- WiFi/Bluetooth require firmware extracted from macOS

---

## Part 1: Pre-Installation (on macOS)

### Step 1.1: Backup Important Data

Before proceeding, backup any data you want to keep from the Mac Mini:

```bash
# Example: Backup to external drive
rsync -avP ~/Documents /Volumes/Backup/mac-mini-backup/
```

### Step 1.2: Backup Plex Server Data (Recommended)

If you're running Plex on this Mac Mini, **backup the Plex data directory** to preserve:

- Watch history and "Continue Watching" progress
- Intro/credits detection markers (takes hours to regenerate)
- Preview thumbnails (timeline scrubbing images)
- User ratings, collections, and playlists
- Matched metadata (avoids re-matching)
- Managed user accounts and their history

```bash
# 1. Stop Plex completely
osascript -e 'quit app "Plex Media Server"'
pkill -f "Plex Media Server" 2>/dev/null

# 2. Verify Plex is stopped
pgrep -f "Plex Media Server" && echo "WARNING: Plex still running!"

# 3. Find the data directory
PLEX_DATA="$HOME/Library/Application Support/Plex Media Server"

# 4. Check the size (can be 10-50GB+ depending on library)
du -sh "$PLEX_DATA"

# 5. Create backup (excluding Cache to save space)
tar --exclude='Cache' --exclude='Crash Reports' --exclude='Logs' \
    -cvzf ~/plex-backup.tar.gz \
    -C "$HOME/Library/Application Support" \
    "Plex Media Server"

# 6. Copy to external drive or NAS
cp ~/plex-backup.tar.gz /Volumes/Backup/
# Or copy to NAS:
# scp ~/plex-backup.tar.gz user@nas:/volume1/backups/
```

**What's in the backup:**

| Directory                   | Contents                            | Size   |
| --------------------------- | ----------------------------------- | ------ |
| `Plug-in Support/Databases` | Main library database               | 1-5GB  |
| `Metadata/`                 | Artwork, posters, backgrounds       | 5-20GB |
| `Media/`                    | Preview thumbnails, analysis data   | 5-30GB |
| `Preferences.xml`           | Server settings (needs path update) | <1MB   |

> **Note**: The backup will be restored in [Part 4: Plex Data Migration](#part-4-plex-data-migration-optional) after NixOS is installed.

### Step 1.3: Extract WiFi/Bluetooth Firmware (Optional, Skip for Ethernet-Only)

If you might need WiFi in the future, extract the Broadcom firmware now:

```bash
# Create a directory for firmware
mkdir -p ~/mac-mini-firmware

# Copy WiFi firmware
cp /usr/share/firmware/wifi/* ~/mac-mini-firmware/

# Copy Bluetooth firmware
cp /usr/share/firmware/bluetooth/* ~/mac-mini-firmware/

# Copy to a USB drive for later
cp -r ~/mac-mini-firmware /Volumes/USB_DRIVE/
```

> **Note**: For server use with Ethernet, WiFi is unnecessary. Skip this if you'll only use Ethernet.

### Step 1.4: Disable T2 Secure Boot

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

### Step 1.5: (Optional) Keep a macOS Recovery Partition

Apple releases T2 firmware updates through macOS. You may want to keep a small macOS partition for future firmware updates.

**Option A: Full wipe (recommended for simplicity)**

- Use entire disk for NixOS
- Accept that you won't get T2 firmware updates without reinstalling macOS

**Option B: Dual boot**

- Keep a 30-50GB macOS partition for firmware updates
- Partition the remaining space for NixOS
- Use macOS Internet Recovery if needed later

### Step 1.6: Download T2-Compatible NixOS ISO

The standard NixOS ISO won't boot on T2 Macs. Use the t2linux project's ISO:

1. **Download the ISO**:
   - Go to: https://github.com/t2linux/nixos-t2-iso/releases
   - Download `t2-iso-minimal-*.iso` (multiple parts if split)
   - If split: `cat t2-iso-minimal-*.iso-part-* > t2-iso-minimal.iso`

2. **Verify the download** (optional but recommended):

   ```bash
   shasum -a 256 t2-iso-minimal.iso
   # Compare with SHA256 on releases page
   ```

3. **Create bootable USB**:

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

> **Troubleshooting**: If the USB doesn't appear, ensure Secure Boot is disabled (Step 1.3)

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

### Step 2.7: Generate Hardware Configuration

```bash
# Generate initial hardware configuration
sudo nixos-generate-config --root /mnt

# View the generated config (will be replaced with our config)
cat /mnt/etc/nixos/hardware-configuration.nix
```

Take note of:

- The Ethernet interface name (e.g., `enp0s31f6`)
- Any additional kernel modules detected
- Filesystem UUIDs (though we use labels)

### Step 2.8: Clone Configuration Repository

```bash
# Install git in the installer environment
nix-env -iA nixos.git

# Clone your goodlab repository
cd /mnt/nix/persist
sudo mkdir -p home/orther/git
cd home/orther/git
sudo git clone https://github.com/orther/goodlab.git

# Set ownership (will be corrected after first boot)
sudo chown -R 1000:100 /mnt/nix/persist/home
```

### Step 2.9: Generate Host SSH Keys

These are required for sops-nix to decrypt secrets:

```bash
# Generate SSH host keys in the persistent secret location
sudo ssh-keygen -t ed25519 -f /mnt/nix/secret/initrd/ssh_host_ed25519_key -N ""
sudo ssh-keygen -t rsa -b 4096 -f /mnt/nix/secret/initrd/ssh_host_rsa_key -N ""

# Get the age public key for .sops.yaml
# NOTE: Save this output - you'll need it for Step 3.2
nix-shell -p age --run "age-keygen -y /mnt/nix/secret/initrd/ssh_host_ed25519_key"
```

**IMPORTANT**: Save the age public key output! It looks like:

```
age1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrs
```

### Step 2.10: Update Configuration for This Host

Edit the hardware configuration if the Ethernet interface name differs:

```bash
# Check the actual interface name
ip link show

# If different from enp0s31f6, edit the configuration
sudo nano /mnt/nix/persist/home/orther/git/goodlab/machines/plex/configuration.nix
# Update: interfaces.enp0s31f6.useDHCP = true;
# To use your actual interface name
```

### Step 2.11: Install NixOS

```bash
# Install using the flake configuration
sudo nixos-install --flake /mnt/nix/persist/home/orther/git/goodlab#plex --no-root-passwd

# Set root password when prompted (or use --no-root-passwd if using keys only)
```

The installation will take 10-30 minutes depending on network speed.

### Step 2.12: First Boot

```bash
# Unmount all partitions
sudo umount -R /mnt

# Reboot
sudo reboot
```

Remove the USB drive when the system starts rebooting.

---

## Part 3: SOPS Secrets Setup

After the first successful boot, you need to configure secrets access.

### Step 3.1: Verify System Boot

After reboot, you should see a login prompt. Log in via:

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

On the new plex server:

```bash
# Get the public key from the SSH host key
sudo nix-shell -p age --run "age-keygen -y /nix/secret/initrd/ssh_host_ed25519_key"
```

Copy this public key (starts with `age1...`).

### Step 3.3: Update .sops.yaml on Another Machine

On a machine that already has access to the secrets (e.g., stud or nblap):

```bash
cd ~/git/goodlab  # or wherever your repo is

# Edit .sops.yaml and replace the placeholder plex key
# Find line: - &plex age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Replace with the actual key from Step 3.2
```

The `.sops.yaml` should look like:

```yaml
keys:
  - &nblap age1pq6uyy9fp43pyxqu9unxjg6nuhuln8psl2lx0exrlpt4ec2s8sgqay5aya
  - &noir age1hychfwplt2rpkzdxvz5lxy7zjf0dt0y6qrcwe2gvnm4mkelsnc7syu2y25
  - &stud age1gz6jjmdce0xjh4c8st4tx5qhd5lpw2527dzfr6davwpjyrrr8ctqnv3p4z
  - &zinc age12pc2l7dyq0tlj0mm56vrwez6yr8nlve6vrucexf7x92dg7qlzcxskrf2tv
  - &vm age1aruj7g3pugj3knq2f5u02tzq6vu5edcjv25veudrsvtr2yzedpusssscpz
  - &plex age1YOUR_ACTUAL_PUBLIC_KEY_HERE
creation_rules:
  - path_regex: secrets/[^/]+(\.(yaml|json|env|ini|conf))?$
    key_groups:
      - age:
          - *nblap
          - *noir
          - *stud
          - *zinc
          - *vm
          - *plex
```

### Step 3.4: Re-encrypt Secrets

```bash
# Update the secrets file to include the new key
cd ~/git/goodlab
sops updatekeys secrets/secrets.yaml
```

When prompted, confirm the key additions.

### Step 3.5: Push Changes and Pull on Plex

```bash
# On the machine where you updated .sops.yaml
git add .sops.yaml secrets/secrets.yaml
git commit -m "feat(plex): add plex host to sops secrets"
git push origin feat/add-plex-host
```

Then on the plex server:

```bash
cd ~/git/goodlab
git pull origin feat/add-plex-host
```

### Step 3.6: Verify Secrets Work

```bash
# Rebuild the system to verify secrets decrypt properly
sudo nixos-rebuild switch --flake ~/git/goodlab#plex
```

If this completes without errors, secrets are working correctly.

---

## Part 4: Plex Data Migration (Optional)

If you backed up Plex data in [Step 1.2](#step-12-backup-plex-server-data-recommended), restore it now to preserve your watch history, intro markers, and metadata.

### Why Migrate?

| Without Migration             | With Migration               |
| ----------------------------- | ---------------------------- |
| Full library rescan (hours)   | Instant library recognition  |
| All watch history lost        | Watch history preserved      |
| Intro detection re-runs       | Intro markers preserved      |
| Preview thumbnails regenerate | Thumbnails ready immediately |
| Must re-fix mismatched items  | All matches preserved        |

### Step 4.1: Copy Backup to Plex Server

Transfer your `plex-backup.tar.gz` to the new NixOS server:

```bash
# Option A: From another machine via SCP
scp /path/to/plex-backup.tar.gz orther@plex-ip:~/

# Option B: From NAS
# On the plex server:
cp /mnt/docker-data/backups/plex-backup.tar.gz ~/
```

### Step 4.2: Stop Plex and Extract Backup

```bash
# Stop Plex service
sudo systemctl stop plex

# Create the target directory if it doesn't exist
sudo mkdir -p /nix/persist/var/lib/plex

# Extract the backup
cd /nix/persist/var/lib/plex
sudo tar -xvzf ~/plex-backup.tar.gz

# The data is now at: /nix/persist/var/lib/plex/Plex Media Server/
```

### Step 4.3: Fix Ownership

The files were owned by your macOS user; fix for the NixOS plex user:

```bash
sudo chown -R plex:plex "/nix/persist/var/lib/plex/Plex Media Server"
```

### Step 4.4: Update Library Paths in Database

**This is critical!** Your media paths changed from macOS to Linux:

| Platform | Example Path            |
| -------- | ----------------------- |
| macOS    | `/Volumes/Media/Movies` |
| NixOS    | `/mnt/media/movies`     |

Update the paths in Plex's database:

```bash
# Install sqlite temporarily
nix-shell -p sqlite

# View current library paths (to see what needs updating)
sqlite3 "/nix/persist/var/lib/plex/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db" \
  "SELECT id, root_path FROM section_locations;"

# Update paths (adjust OLD_PATH and NEW_PATH for your setup)
# Example: /Volumes/Media -> /mnt/media
sqlite3 "/nix/persist/var/lib/plex/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db" \
  "UPDATE section_locations SET root_path = REPLACE(root_path, '/Volumes/Media', '/mnt/media');"

# Verify the update
sqlite3 "/nix/persist/var/lib/plex/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db" \
  "SELECT id, root_path FROM section_locations;"

# Exit nix-shell
exit
```

**Common path mappings:**

| macOS Path           | NixOS Path           |
| -------------------- | -------------------- |
| `/Volumes/Media/`    | `/mnt/media/`        |
| `/Volumes/Movies/`   | `/mnt/media/movies/` |
| `/Volumes/TV Shows/` | `/mnt/media/tv/`     |
| `/Users/*/Movies/`   | `/mnt/media/movies/` |

### Step 4.5: Start Plex and Verify

```bash
# Start Plex
sudo systemctl start plex

# Check status
sudo systemctl status plex

# Watch logs for errors
journalctl -u plex -f
```

### Step 4.6: Verify Migration in Web UI

1. Access Plex at `http://plex-ip:32400/web`
2. **Sign in** with your Plex account (the server should already be claimed)
3. Check your libraries - they should show your existing content
4. Verify:
   - Watch history is intact (check "Continue Watching")
   - Library counts match your old server
   - Intro markers work (play a TV episode)
   - Preview thumbnails appear in timeline

### Troubleshooting Migration

**Libraries show "unavailable" or empty:**

- Path update didn't work - re-run Step 4.4
- NFS mount not ready - check `mount | grep nfs`
- Permissions issue - re-run Step 4.3

**Server not claimed / asks to sign in again:**

- The server token is tied to the machine ID
- You may need to re-claim the server (this is normal)
- Your libraries and history are preserved; only server ownership changes

**Database locked errors:**

```bash
# Ensure Plex is stopped
sudo systemctl stop plex
# Then retry the sqlite commands
```

**Some metadata missing:**

- This is normal for items Plex couldn't match paths for
- Run "Scan Library Files" in Plex to re-match
- Check that all path replacements were correct

---

## Part 5: Post-Installation Configuration

### Step 5.1: Verify Hardware Transcoding

Check that the Intel GPU is properly configured:

```bash
# Check GPU device nodes exist
ls -la /dev/dri/
# Expected output:
# crw-rw---- 1 root video 226,   0 ... card0
# crw-rw---- 1 root render 226, 128 ... renderD128

# Verify VA-API is working (this is the main driver Plex uses)
vainfo
# Should show "libva info: VA-API version: 1.x"
# And list supported profiles like VAProfileH264Main, VAProfileHEVCMain, etc.
# The intel-media-driver provides these via the iHD driver

# Check that Plex user has GPU access
groups plex
# Should include: video render
```

### Step 5.2: Configure NAS Media Mount (Fresh Install Only)

Update the NAS details in the configuration:

```bash
# Edit the plex service configuration
sudo nano ~/git/goodlab/services/plex.nix

# Update this line with your actual NAS details:
#   device = "10.4.0.50:/volume1/media";
# For example:
#   device = "192.168.1.100:/volume1/Media";
```

Rebuild and verify the mount:

```bash
# Rebuild
sudo nixos-rebuild switch --flake ~/git/goodlab#plex

# Trigger automount by accessing the directory
ls /mnt/media

# Check mount status
mount | grep media
# Should show: 192.168.1.100:/volume1/Media on /mnt/media type nfs4

# Verify Plex can read the files
sudo -u plex ls /mnt/media
```

### Step 5.3: Initial Plex Setup (Fresh Install Only)

**If accessing locally:**

- Open a browser on a device on the same network
- Navigate to: `http://<plex-ip>:32400/web`

**If accessing remotely (via SSH tunnel):**

```bash
# Create SSH tunnel from your local machine
ssh -L 32400:localhost:32400 orther@plex-ip

# Then open in browser:
# http://localhost:32400/web
```

1. **Sign in** with your Plex account
2. **Claim the server** (links it to your account)
3. **Configure server settings**:
   - **Settings → Server → General**: Name your server
   - **Settings → Server → Network**: Enable remote access if desired
4. **Enable hardware transcoding**:
   - **Settings → Server → Transcoder**
   - Check **"Use hardware acceleration when available"**
   - Check **"Use hardware-accelerated video encoding"**
5. **Add media libraries** (skip if you migrated data):
   - Click **"Add Library"**
   - Select type (Movies, TV Shows, Music, etc.)
   - Add folders:
     - Movies: `/mnt/media/movies`
     - TV Shows: `/mnt/media/tv`

### Step 5.4: Verify Hardware Transcoding in Plex

1. Play a video that requires transcoding (different resolution/codec than source)
2. Open Plex Dashboard (**Settings → Manage → Dashboard**)
3. Look at the "Now Playing" section
4. Transcoding should show **(hw)** indicator:
   ```
   Direct Play → 1080p (h264) - No transcoding
   Transcode (hw) → 720p (h264) - Hardware transcoding active
   Transcode → 720p (h264) - CPU transcoding (indicates GPU issue)
   ```

**Force transcoding test:**

- On a client, change quality settings to a lower resolution
- Play any video and verify **(hw)** appears

### Step 5.5: Monitor GPU Usage

```bash
# Install and run Intel GPU monitoring
intel_gpu_top

# During transcoding, you should see:
# - Render/3D engine activity
# - Video engine activity (this is Quick Sync)
```

---

## Part 6: Maintenance & Troubleshooting

### Updating the System

```bash
# Pull latest configuration changes
cd ~/git/goodlab
git pull

# Update flake inputs (optional, for package updates)
nix flake update

# Rebuild the system
sudo nixos-rebuild switch --flake .#plex
```

### Common Issues

#### 1. T2-Specific Boot Issues

**Symptom**: System hangs during boot or kernel panic

**Solutions**:

- Ensure Secure Boot is disabled (see Step 1.3)
- Try booting with `nomodeset` kernel parameter temporarily
- Check that you're using the t2linux kernel (not mainline)

#### 2. NAS Mount Failures

**Symptom**: `/mnt/media` is empty or mount fails

**Diagnosis**:

```bash
# Check mount status
systemctl status mnt-media.mount
systemctl status mnt-media.automount

# Check if NAS is reachable
ping <NAS_IP>

# Try manual mount
sudo mount -t nfs -o nfsvers=4.1 <NAS_IP>:/path/to/share /mnt/test

# Check NFS exports on NAS
showmount -e <NAS_IP>
```

**Common fixes**:

- Verify NFS server is enabled on NAS
- Check NAS firewall allows NFS from plex IP
- Ensure export path is correct (case-sensitive!)
- Try different NFS version (4.2, 4.1, 4.0, 3)

#### 3. Plex Hardware Transcoding Not Working

**Symptom**: Transcoding shows no "(hw)" indicator, or uses CPU

**Diagnosis**:

```bash
# Check GPU access
ls -la /dev/dri/renderD128
# Should show: crw-rw---- 1 root render ...

# Check Plex user groups
groups plex
# Must include: video render

# Check VA-API
vainfo 2>&1 | head -20
# Should show driver info and profiles

# Check Plex logs
tail -f /var/lib/plex/Plex\ Media\ Server/Logs/Plex\ Transcoder.log
```

**Common fixes**:

- Rebuild with: `sudo nixos-rebuild switch --flake .#plex`
- Restart Plex: `sudo systemctl restart plex`
- Ensure `/dev/dri/renderD128` is in `accelerationDevices`
- Check Plex Transcoder settings (hardware acceleration enabled)

#### 4. GPU Not Accessible

**Symptom**: `vainfo` shows "failed to initialize" or no GPU

**Diagnosis**:

```bash
# Check kernel module is loaded
lsmod | grep i915

# Check dmesg for GPU errors
dmesg | grep -i "drm\|i915\|gpu"

# Check that GuC is enabled
cat /sys/kernel/debug/dri/0/gt/uc/guc_info
```

**Solutions**:

- Ensure `hardware.graphics.enable = true` is set
- Check kernel parameters include `i915.enable_guc=2`
- Try without GuC: remove the kernel parameter and rebuild

#### 5. Secrets Decryption Failures

**Symptom**: `nixos-rebuild` fails with sops errors

**Diagnosis**:

```bash
# Check the SSH key exists
ls -la /nix/secret/initrd/ssh_host_ed25519_key

# Verify the key matches .sops.yaml
nix-shell -p age --run "age-keygen -y /nix/secret/initrd/ssh_host_ed25519_key"
# Compare with &plex entry in .sops.yaml

# Test decryption manually
cd ~/git/goodlab
nix-shell -p sops --run "sops -d secrets/secrets.yaml"
```

**Solutions**:

- Re-run `sops updatekeys` on a machine with existing access
- Verify the public key in .sops.yaml matches the actual key
- Ensure `/nix/secret/initrd/` path matches `sops.age.sshKeyPaths` in base.nix

### Rollback Procedure

#### Boot into Previous Generation

1. Reboot the system
2. At the systemd-boot menu, select an older generation
3. System will boot with that configuration

#### Rollback from Command Line

```bash
# List available generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Switch to a specific generation
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation <number>
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### Log Locations

| Log            | Location/Command                        |
| -------------- | --------------------------------------- |
| System journal | `journalctl -b`                         |
| Plex logs      | `/var/lib/plex/Plex Media Server/Logs/` |
| Mount issues   | `journalctl -u mnt-media.mount`         |
| GPU/driver     | `dmesg \| grep -i drm`                  |
| SSH            | `journalctl -u sshd`                    |
| Boot           | `journalctl -b -p err`                  |

### Useful Commands Reference

```bash
# System status
systemctl status plex
systemctl status tailscaled

# Rebuild system
sudo nixos-rebuild switch --flake ~/git/goodlab#plex

# Update and rebuild
cd ~/git/goodlab && git pull && sudo nixos-rebuild switch --flake .#plex

# Check hardware acceleration
vainfo
intel_gpu_top

# Network diagnostics
ip addr show
ping <NAS_IP>
mount | grep nfs

# Plex service management
sudo systemctl restart plex
sudo systemctl status plex
journalctl -u plex -f
```

---

## Appendix: File Reference

### Configuration Files

| File                                       | Purpose                    |
| ------------------------------------------ | -------------------------- |
| `machines/plex/configuration.nix`          | Main host configuration    |
| `machines/plex/hardware-configuration.nix` | Hardware-specific settings |
| `services/plex.nix`                        | Plex service and NAS mount |
| `modules/nixos/base.nix`                   | Common NixOS settings      |
| `.sops.yaml`                               | Secrets encryption keys    |

### Key Directories on Plex Server

| Path            | Purpose                              |
| --------------- | ------------------------------------ |
| `/nix/persist`  | Persistent storage (survives reboot) |
| `/nix/secret`   | SSH keys for sops-nix                |
| `/var/lib/plex` | Plex database and metadata           |
| `/mnt/media`    | NAS media mount point                |
| `~/git/goodlab` | NixOS configuration repo             |

---

## Quick Start Checklist

### Pre-Installation (macOS)

- [ ] Backup Mac Mini data
- [ ] Backup Plex data (if migrating)
- [ ] Disable T2 Secure Boot
- [ ] Download and flash t2linux NixOS ISO

### Installation

- [ ] Boot from USB and partition disk
- [ ] Mount filesystems and generate config
- [ ] Clone goodlab repo and generate SSH keys
- [ ] Install NixOS with `nixos-install --flake`
- [ ] Boot into NixOS and verify login

### Configuration

- [ ] Update .sops.yaml with plex age key
- [ ] Re-encrypt secrets and rebuild

### Plex Setup (Choose One)

**Option A: Fresh Install**

- [ ] Access Plex web UI and claim server
- [ ] Enable hardware transcoding
- [ ] Add media libraries (`/mnt/media/movies`, `/mnt/media/tv`)
- [ ] Verify transcoding shows (hw)

**Option B: Migration from macOS**

- [ ] Copy Plex backup to server
- [ ] Extract backup and fix ownership
- [ ] Update library paths in database
- [ ] Verify watch history and libraries
- [ ] Verify transcoding shows (hw)
