{
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager

    ./hardware-configuration.nix

    inputs.self.nixosModules.base
    inputs.self.nixosModules."remote-unlock"
    inputs.self.nixosModules."auto-update"

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
          inputs.self.lib.hmModules.base
        ];
      };
    };
  };

  networking.hostName = "svr3chng";
}
