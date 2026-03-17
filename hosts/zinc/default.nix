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
    inputs.self.nixosModules."auto-update"

    ./../../services/tailscale.nix
    ./../../services/router-zinc.nix
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
    useNetworkd = true;
    networkmanager.enable = lib.mkForce false;
  };

  # Advertise the condo LAN subnet over Tailscale
  services.tailscale.extraUpFlags = lib.mkForce [
    "--advertise-routes=10.0.0.0/24"
    "--accept-dns=true"
  ];

  # Disable wait services — NetworkManager→networkd transition is complete,
  # but networkd-wait-online without per-interface config can stall boot if
  # enp2s0 (LAN) is unplugged. Leave disabled until routing is stable.
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };
}
