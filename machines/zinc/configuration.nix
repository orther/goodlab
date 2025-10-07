{
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager
    #inputs.nixarr.nixosModules.default

    ./hardware-configuration.nix

    inputs.self.nixosModules.base
    inputs.self.nixosModules."remote-unlock"
    inputs.self.nixosModules."auto-update"

    ./../../services/tailscale.nix
    #./../../services/netdata.nix
    #./../../services/nextcloud.nix
    #./../../services/nixarr.nix

    # Research Relay services (zinc = BTCPay Server)
    ./../../services/research-relay/_common-hardening.nix
    ./../../services/research-relay/btcpay.nix
    ./../../services/research-relay/secrets.nix
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

  networking = {
    hostName = "zinc";
    useDHCP = false;
    interfaces.enp1s0.useDHCP = true;
    useNetworkd = true;
  };

  # Enable Research Relay BTCPay Server on zinc
  services.researchRelay = {
    btcpay.enable = true;
  };
}
