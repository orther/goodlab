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

        # Corporate network CA certificates for Elixir/Hex, Node.js, and AWS CLI
        home.sessionVariables = {
          HEX_CACERTS_PATH = "/opt/homebrew/etc/ca-certificates/cert.pem";
          NODE_EXTRA_CA_CERTS = "/opt/homebrew/etc/ca-certificates/cert.pem";
          AWS_CA_BUNDLE = "/opt/homebrew/etc/ca-certificates/cert.pem";
        };

        # Enable AWS SSM configuration for CareCar infrastructure access
        programs.aws-ssm = {
          enable = true;
          enableSshProxy = true;
          enableCareCar = true;
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
