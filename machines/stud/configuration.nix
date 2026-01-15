{
  config,
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops

    ./hardware-configuration.nix

    inputs.self.darwinModules.base
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {
        imports = [
          inputs.self.lib.hmModules.base
          inputs.self.lib.hmModules.fonts
          inputs.self.lib.hmModules.alacritty
          inputs.self.lib.hmModules."1password"
          inputs.self.lib.hmModules.doom
          inputs.self.lib.hmModules.claude-code
        ];
      };
    };
  };

  sops = {
    defaultSopsFile = ./../../secrets/secrets.yaml;
    age.keyFile = "/Users/${config.system.primaryUser}/.config/sops/age/keys.txt";
  };

  networking = {
    hostName = "stud";
    computerName = "stud";
    localHostName = "stud";
  };
}
