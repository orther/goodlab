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
        ];
        # Override defaults from HM base for this host
        home.username = lib.mkForce "brandon.orther";
        home.homeDirectory = lib.mkForce "/Users/brandon.orther";
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
