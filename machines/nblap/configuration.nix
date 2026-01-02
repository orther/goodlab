{
  inputs,
  outputs,
  lib,
  ...
}: {
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops

    ./hardware-configuration.nix

    ./../../modules/macos/work.nix
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      "brandon.orther" = {
        imports = [
          inputs.self.lib.hmModules.base
          inputs.self.lib.hmModules.fonts
          inputs.self.lib.hmModules.alacritty
          inputs.self.lib.hmModules."1password"
          inputs.self.lib.hmModules.doom
          inputs.self.lib.hmModules.aws-ssm
        ];
        # Override defaults from HM base for this host
        home.username = lib.mkForce "brandon.orther";
        home.homeDirectory = lib.mkForce "/Users/brandon.orther";

        # Corporate network CA certificates - use Zscaler-managed bundle
        # The zscaler module automatically extracts and updates certificates from macOS keychain
        home.sessionVariables = {
          # Use Zscaler-managed certificates for all tools
          HEX_CACERTS_PATH = "/etc/ssl/nix-corporate/ca-bundle.pem";
          NODE_EXTRA_CA_CERTS = "/etc/ssl/nix-corporate/ca-bundle.pem";
          AWS_CA_BUNDLE = "/etc/ssl/nix-corporate/ca-bundle.pem";

          # Fallback to homebrew if Zscaler certs unavailable (shouldn't happen)
          # HEX_CACERTS_PATH = "/opt/homebrew/etc/ca-certificates/cert.pem";
          # NODE_EXTRA_CA_CERTS = "/opt/homebrew/etc/ca-certificates/cert.pem";
          # AWS_CA_BUNDLE = "/opt/homebrew/etc/ca-certificates/cert.pem";
        };

        # Enable AWS SSM configuration for CareCar infrastructure access
        programs.aws-ssm = {
          enable = true;
          enableSshProxy = true;
          enableCareCar = true;
          region = "us-west-2";
          bastionTag = "bastion";

          # Database endpoints for SSM port forwarding
          databases = {
            acceptance = {
              host = "acceptance-db.cbpfxk1gzmnb.us-west-2.rds.amazonaws.com";
              port = 5432;
              localPort = 5434;
            };
            production = {
              host = "prod-db.c53hlgaegw8h.us-west-2.rds.amazonaws.com";
              port = 5432;
              localPort = 5433;
            };
          };
        };
      };
    };
  };

  sops = {
    defaultSopsFile = ./../../secrets/secrets.yaml;
    age.keyFile = "/Users/brandon.orther/.config/sops/age/keys.txt";
  };

  networking = {
    hostName = "nblap";
    computerName = "nblap";
    localHostName = "nblap";
  };
}
