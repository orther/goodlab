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

    ./../../services/nas.nix
    ./../../services/tailscale.nix
    #./../../services/netdata.nix
    #./../../services/nextcloud.nix
    #./../../services/nixarr.nix

    # Research Relay services (noir = Odoo + PDF-intake)
    ./../../services/research-relay/_common-hardening.nix
    ./../../services/research-relay/odoo.nix
    ./../../services/research-relay/pdf-intake.nix
    ./../../services/research-relay/secrets.nix
  ];

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
          userName = "Brandon Orther";
          userEmail = "brandon@orther.dev";
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
    networkmanager.enable = lib.mkForce false; # Override base.nix NetworkManager setting
  };

  # Disable problematic wait services during NetworkManager -> systemd-networkd transition
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };

  # Enable Research Relay services on noir
  services.researchRelay = {
    odoo.enable = true;
    pdfIntake.enable = true;
  };
}
