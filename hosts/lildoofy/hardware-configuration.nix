# Hardware configuration for Hetzner Cloud VPS (QEMU/KVM)
# Uses BIOS boot with GRUB (Hetzner Cloud uses legacy BIOS, not UEFI)
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disko-config.nix
  ];

  boot = {
    loader.grub = {
      enable = true;
      devices = lib.mkForce ["/dev/sda"]; # Install GRUB to MBR (force to prevent duplicates)
      # No EFI support - Hetzner Cloud uses BIOS boot
    };
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];
  };

  # Disk layout comes from disko-config.nix
  # Do not duplicate filesystem definitions here

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
