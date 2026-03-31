{
  inputs,
  outputs,
  lib,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager
    #inputs.nixarr.nixosModules.default

    ./hardware-configuration.nix

    inputs.self.nixosModules.base
    inputs.self.nixosModules."remote-unlock"
    inputs.self.nixosModules."auto-update"

    # Infrastructure
    ./../../services/nas.nix
    ./../../services/tailscale.nix
    ./../../services/_acme.nix
    ./../../services/_nginx.nix
    ./../../services/cloudflare-tunnel-noir.nix

    # Home automation
    ./../../services/home-assistant.nix

    # Media management (*arr stack)
    ./../../services/sonarr.nix
    ./../../services/radarr.nix
    ./../../services/prowlarr.nix
    ./../../services/nzbget.nix

    # Media request & user management
    ./../../services/jellyseerr.nix
    ./../../services/wizarr.nix

    # Adult content management
    ./../../services/stash.nix
    ./../../services/whisparr.nix

    # Monitoring
    ./../../services/tautulli.nix
    ./../../services/jellystat.nix
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {...}: {
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
            # Add more hosts as needed
          };
        };
      };
    };
  };

  networking = {
    hostName = "noir";
    useDHCP = false;
    interfaces.enp2s0.useDHCP = true;
    useNetworkd = true;
    networkmanager.enable = lib.mkForce false;
  };

  # ==========================================================================
  # Media Directory Symlink
  # ==========================================================================
  # Create symlink for cleaner media paths (matches pie's layout):
  #   /mnt/media -> /mnt/docker-data/media

  systemd.tmpfiles.rules = [
    "L+ /mnt/media - - - - /mnt/docker-data/media"
  ];

  # Disable problematic wait services during NetworkManager -> systemd-networkd transition
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };
}
