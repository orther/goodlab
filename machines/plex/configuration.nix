# NixOS configuration for Plex Media Server on 2018 Mac Mini
#
# This configuration is optimized for a dedicated Plex server with:
# - Intel Quick Sync Video hardware transcoding
# - Apple T2 chip support via nixos-hardware
# - NFS media mount from NAS
# - Headless operation (no desktop environment)
{
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Apple T2 Mac support (kernel, firmware, audio)
    inputs.nixos-hardware.nixosModules.apple-t2

    # Impermanence and Home Manager
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager

    # Hardware configuration
    ./hardware-configuration.nix

    # Base NixOS modules
    inputs.self.nixosModules.base

    # Services
    ./../../services/tailscale.nix
    ./../../services/nas.nix # Mounts /mnt/docker-data from NAS
    ./../../services/plex.nix
  ];

  # Home Manager configuration
  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {
        imports = [
          inputs.self.lib.hmModules.base
        ];

        programs.git = {
          enable = true;
          settings = {
            user = {
              name = "Brandon Orther";
              email = "brandon@orther.dev";
            };
          };
        };

        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          matchBlocks = {
            "github.com" = {
              hostname = "github.com";
              identityFile = "~/.ssh/id_ed25519";
            };
          };
        };
      };
    };
  };

  # ==========================================================================
  # Network Configuration
  # ==========================================================================
  networking = {
    hostName = "plex";
    useDHCP = false;
    useNetworkd = true;

    # Ethernet interface - name will be confirmed after first boot
    # Common names: enp0s31f6, eno1, enp2s0f0
    # Run `ip link` after boot to verify and update if needed
    interfaces.enp0s31f6.useDHCP = true;

    # Disable NetworkManager in favor of simpler systemd-networkd for servers
    networkmanager.enable = lib.mkForce false;

    # Explicitly disable WiFi - Ethernet only for server reliability
    wireless.enable = false;
  };

  # Disable network wait services to prevent boot hangs if network is slow
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };

  # ==========================================================================
  # Intel Quick Sync Video - Hardware Transcoding
  # ==========================================================================
  # The UHD 630 (Coffee Lake) supports HEVC/H.265, H.264, VP8, VP9, and JPEG
  # hardware encoding/decoding via Intel Quick Sync Video technology.

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # VA-API driver for Broadwell (2014) and newer - required for hardware transcoding
      # This is the modern "iHD" driver that Plex uses for video encoding/decoding
      intel-media-driver

      # Intel Video Processing Library runtime
      # While officially for 11th gen+, provides broader compatibility than
      # the deprecated intel-media-sdk (which has unpatched CVEs)
      vpl-gpu-rt

      # OpenCL support for HDR tone mapping in Plex
      intel-compute-runtime
    ];
  };

  # Force the iHD VA-API driver (not the older i965 driver)
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Enable redistributable firmware for Intel graphics and other hardware
  hardware.enableRedistributableFirmware = true;

  # ==========================================================================
  # Apple T2 Configuration
  # ==========================================================================
  # The nixos-hardware apple-t2 module handles most T2-specific settings.
  # Additional configuration options if needed:

  hardware.apple-t2 = {
    # Use stable kernel channel (recommended for server stability)
    kernelChannel = "stable";

    # Enable WiFi/Bluetooth firmware (disabled since we use Ethernet only)
    firmware.enable = false;
  };

  # ==========================================================================
  # Plex Service Configuration
  # ==========================================================================
  # Plex service is configured in services/plex.nix
  # Here we just ensure the plex user has proper GPU access

  # Plex user needs video and render group membership for GPU access
  users.users.plex.extraGroups = ["video" "render"];

  # ==========================================================================
  # Server Optimizations
  # ==========================================================================

  # No desktop environment needed
  services.xserver.enable = false;

  # Disable sleep/hibernate - server should always be available
  # Use mkForce to override apple-t2 module's default (which enables power management)
  powerManagement = {
    enable = lib.mkForce false;
    powertop.enable = false;
  };
  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";
  services.logind.lidSwitchExternalPower = "ignore";

  # Server-specific boot settings
  boot.loader.timeout = 3; # Faster boot, less waiting
}
