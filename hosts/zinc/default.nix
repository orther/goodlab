{
  inputs,
  outputs,
  lib,
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
    ./../../services/home-assistant-zinc.nix
    ./../../services/unifi-zinc.nix
    ./../../services/cloudflare-tunnel-zinc.nix
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
    networkmanager.enable = lib.mkForce false;
  };

  # Override Tailscale route for condo network (192.168.1.x)
  services.tailscale.extraUpFlags = lib.mkForce [
    "--advertise-routes=192.168.1.0/24"
    "--accept-dns=true"
  ];

  # Disable problematic wait services during NetworkManager -> systemd-networkd transition
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };
}
