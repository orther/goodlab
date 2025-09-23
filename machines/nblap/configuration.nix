{
  inputs,
  outputs,
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
          ./../../modules/home-manager/base.nix
          ./../../modules/home-manager/fonts.nix
          ./../../modules/home-manager/alacritty.nix
          ./../../modules/home-manager/1password.nix
          ./../../modules/home-manager/doom.nix
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
