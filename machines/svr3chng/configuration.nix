{
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager

    ./hardware-configuration.nix

    ./../../modules/nixos/base.nix
    ./../../modules/nixos/remote-unlock.nix
    ./../../modules/nixos/auto-update.nix

    ./../../services/tailscale.nix
    # ./../../services/netdata.nix
    ./../../services/homebridge.nix
    ./../../services/scrypted.nix
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {
        imports = [
          ./../../modules/home-manager/base.nix
        ];
      };
    };
  };

  networking.hostName = "svr3chng";
}
