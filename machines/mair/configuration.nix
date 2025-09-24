{
  config,
  inputs,
  outputs,
  lib,
  ...
}: {
  imports = [
    inputs.home-manager.darwinModules.home-manager

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
          ./../../modules/home-manager/base.nix
          ./../../modules/home-manager/fonts.nix
          ./../../modules/home-manager/alacritty.nix
          ./../../modules/home-manager/1password.nix
          ./../../modules/home-manager/doom.nix
        ];
      };
    };
  };

  networking = {
    hostName = "mair";
    computerName = "mair";
    localHostName = "mair";
  };
}
