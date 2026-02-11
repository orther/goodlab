# Minimal lildoofy configuration for initial nixos-anywhere install
# After install completes, deploy full config via: just deploy lildoofy 168.119.116.225
{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager

    ./hardware-configuration.nix

    inputs.self.nixosModules.base
  ];

  # --- SSH Access ---
  users.users.orther.openssh.authorizedKeys.keys = [
    # lildoofy_admin_ed25519.pub - dedicated admin key for this VPS
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIODzc3LPRHmaxwPf5Exc6mrFs8tCcl6p3QKXz6mDuIB/ lildoofy-admin"
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {...}: {
        imports = [
          inputs.self.lib.hmModules.server-base
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
      };
    };
  };

  # --- Boot Loader Override ---
  # base.nix enables systemd-boot + EFI, but Hetzner Cloud uses BIOS boot
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # --- SOPS Override ---
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  sops.defaultSopsFile = lib.mkForce ./../../secrets/lildoofy-secrets.yaml;
  sops.secrets."user-password" = {};
  # tailscale-authkey not needed in minimal config

  # --- Networking ---
  # Allow public SSH during initial setup (before SOPS/Tailscale work)
  services.openssh.openFirewall = true;

  # Tailscale disabled in minimal config - enable after SOPS keys are set up
  # services.tailscale = {
  #   enable = true;
  #   authKeyFile = config.sops.secrets."tailscale-authkey".path;
  #   openFirewall = false;
  #   useRoutingFeatures = "client";
  #   extraUpFlags = ["--accept-dns=true"];
  # };

  networking = {
    hostName = "lildoofy";
    useDHCP = true;
    useNetworkd = true;
    networkmanager.enable = lib.mkForce false;

    firewall = {
      enable = true;
      allowedTCPPorts = [22]; # Public SSH for initial setup
    };
  };

  # --- Disable wait-online services ---
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };
}
