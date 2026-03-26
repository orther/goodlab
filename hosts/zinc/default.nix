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

  # Advertise the condo LAN subnet over Tailscale.
  # Exit node lets you route all traffic through home when on public WiFi.
  # Accept-routes enables reaching subnets behind other Tailscale nodes.
  services.tailscale.extraUpFlags = lib.mkForce [
    "--advertise-routes=10.0.0.0/24"
    "--advertise-exit-node"
    # Do NOT use --accept-routes on zinc — it causes zinc to route its own
    # LAN subnet (10.0.0.0/24) through Tailscale instead of enp2s0, breaking
    # all LAN connectivity. Zinc is the subnet router, not a client.
    "--accept-dns=true"
  ];

  # SSH — restrict to LAN + Tailscale (no WAN exposure).
  # base.nix sets openFirewall = true which opens port 22 on all interfaces.
  # Override to only allow SSH on enp2s0 (LAN). Tailscale SSH works automatically
  # via its own ts-input iptables chain — no firewall rule needed.
  services.openssh.openFirewall = lib.mkForce false;
  networking.firewall.interfaces.enp2s0.allowedTCPPorts = [22];

  # Brute-force protection — bans IPs after 3 failed SSH attempts.
  # Belt-and-suspenders with Change 3 (SSH restricted to LAN + Tailscale).
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment.enable = true; # Repeat offenders get longer bans
  };

  # Persist fail2ban ban database across reboots (impermanence)
  environment.persistence."/nix/persist".directories = [
    "/var/lib/fail2ban"
  ];

  # Disable wait services — NetworkManager→networkd transition is complete,
  # but networkd-wait-online without per-interface config can stall boot if
  # enp2s0 (LAN) is unplugged. Leave disabled until routing is stable.
  systemd.services = {
    "NetworkManager-wait-online".enable = lib.mkForce false;
    "systemd-networkd-wait-online".enable = lib.mkForce false;
  };
}
