{
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops

    ./hardware-configuration.nix

    ./../../modules/macos/base.nix
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {
        imports = [
          ./../../modules/home-manager/base.nix
          ./../../modules/home-manager/fonts.nix
          ./../../modules/home-manager/alacritty.nix
          ./../../modules/home-manager/1password.nix
          ./../../modules/home-manager/doom.nix
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
