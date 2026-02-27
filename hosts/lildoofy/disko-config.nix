# Disko configuration for Hetzner Cloud VPS
# Uses GPT + BIOS boot (Hetzner Cloud uses legacy BIOS, not UEFI)
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda"; # Standard Hetzner Cloud disk
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot partition for GRUB on GPT
            boot = {
              size = "1M";
              type = "EF02"; # BIOS boot partition
            };
            # /boot partition (ext4, not EFI)
            boot-fs = {
              size = "512M";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
              };
            };
            # /nix partition for persistent storage
            nix = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/nix";
              };
            };
          };
        };
      };
    };
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = ["defaults" "size=2G" "mode=0755"];
      };
    };
  };
}
