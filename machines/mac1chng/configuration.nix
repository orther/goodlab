{
  inputs,
  outputs,
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
          inputs.self.lib.hmModules.base
          inputs.self.lib.hmModules.fonts
          inputs.self.lib.hmModules.alacritty
          inputs.self.lib.hmModules."1password"
        ];
      };
    };
  };

  networking = {
    hostName = "mac1chng";
    computerName = "mac1chng";
    localHostName = "mac1chng";
  };
}
