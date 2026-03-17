# ==============================================================================
# Router - Zinc (Condo)
# ==============================================================================
#
# Turns zinc into the condo's primary router:
#   - enp1s0 (WAN)  → Spectrum modem, DHCP from ISP
#   - enp2s0 (LAN)  → USW 24 PoE, serves 10.0.0.0/24
#   - enp4s0 (Mgmt) → 192.168.254.0/24
#
# Services:
#   - NAT (iptables MASQUERADE on enp1s0)
#   - Kea DHCPv4 (10.0.0.0/24, MAC reservations for known devices)
#   - dnsmasq (LAN DNS forwarder on 10.0.0.1, upstream: Cloudflare)
#
# DHCP reservations — add new devices here after cutover:
#   { hw-address = "xx:xx:xx:xx:xx:xx"; ip-address = "10.0.0.x"; hostname = "name"; }
#
# ==============================================================================
{...}: {
  # ==========================================================================
  # IP forwarding
  # ==========================================================================

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # ==========================================================================
  # Interface pinning (MAC → predictable name)
  # ==========================================================================
  # Ensures NIC ports always map to the same interface names regardless of
  # kernel enumeration order.

  systemd.network.links = {
    "10-wan" = {
      matchConfig.MACAddress = "00:e2:69:53:c6:7d";
      linkConfig.Name = "enp1s0";
    };
    "10-lan" = {
      matchConfig.MACAddress = "00:e2:69:53:c6:7e";
      linkConfig.Name = "enp2s0";
    };
    "10-mgmt" = {
      matchConfig.MACAddress = "00:e2:69:53:c6:80";
      linkConfig.Name = "enp4s0";
    };
  };

  # ==========================================================================
  # Network interfaces
  # ==========================================================================

  networking = {
    interfaces = {
      enp2s0.ipv4.addresses = [{
        address = "10.0.0.1";
        prefixLength = 24;
      }];
      enp4s0.ipv4.addresses = [{
        address = "192.168.254.1";
        prefixLength = 24;
      }];
    };

    # NAT — masquerade LAN traffic behind the WAN IP
    nat = {
      enable = true;
      externalInterface = "enp1s0";
      internalInterfaces = ["enp2s0"];
    };

    # Firewall — LAN-side DHCP and DNS
    firewall.interfaces.enp2s0 = {
      allowedUDPPorts = [53 67];
      allowedTCPPorts = [53];
    };
  };

  # ==========================================================================
  # DHCP server (Kea)
  # ==========================================================================

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = ["enp2s0"];

      subnet4 = [{
        subnet = "10.0.0.0/24";
        pools = [{pool = "10.0.0.200 - 10.0.0.254";}];
        option-data = [
          {name = "routers";            data = "10.0.0.1";}
          {name = "domain-name-servers"; data = "10.0.0.1";}
          {name = "broadcast-address";  data = "10.0.0.255";}
        ];
        reservations = [
          # --- Network infrastructure ---
          {hw-address = "74:ac:b9:e4:bb:36"; ip-address = "10.0.0.2";   hostname = "usw24";}
          {hw-address = "d0:21:f9:51:a9:71"; ip-address = "10.0.0.4";   hostname = "u6pro";}
          {hw-address = "74:ac:b9:a3:c2:85"; ip-address = "10.0.0.5";   hostname = "u6lite";}

          # --- Workstations ---
          {hw-address = "9c:76:0e:78:4d:52"; ip-address = "10.0.0.30";  hostname = "stud-eth";}
          {hw-address = "9c:76:0e:67:e9:6a"; ip-address = "10.0.0.50";  hostname = "stud-wifi";}
          {hw-address = "3c:22:fb:2e:85:e5"; ip-address = "10.0.0.51";  hostname = "mair-wifi";}

          # --- Personal mobile ---
          {hw-address = "1c:3c:78:0e:b5:62"; ip-address = "10.0.0.100"; hostname = "brandon-iphone";}
          # ryatt-tablet: add after cutover when tablet is home

          # --- IoT / Home Automation ---
          {hw-address = "54:ef:fe:12:1f:96"; ip-address = "10.0.0.141"; hostname = "sleeptracker";}
          {hw-address = "60:09:c3:0f:01:88"; ip-address = "10.0.0.142"; hostname = "bios-lamp";}

          # --- Streaming ---
          {hw-address = "20:1f:3b:28:c2:7d"; ip-address = "10.0.0.160"; hostname = "chromecast-1";}
          # Additional Chromecasts / Apple TV: add after cutover
        ];
      }];

      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };

      # 24-hour leases
      valid-lifetime = 86400;
    };
  };

  # ==========================================================================
  # DNS forwarder (dnsmasq)
  # ==========================================================================
  # Listens only on enp2s0 (10.0.0.1). Forwards upstream to Cloudflare.
  # Zinc's own resolver (systemd-resolved on 127.0.0.53) is unaffected.

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "enp2s0";
      bind-interfaces = true;
      # Don't read /etc/resolv.conf — it points to systemd-resolved stub
      no-resolv = true;
      server = ["1.1.1.1" "1.0.0.1"];
      cache-size = 1000;
    };
  };

  # ==========================================================================
  # Persistence (Impermanence) — Kea lease database
  # ==========================================================================

  systemd.tmpfiles.rules = [
    "d /nix/persist/var/lib/kea 0755 kea kea - -"
  ];

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/kea";
        user = "kea";
        group = "kea";
        mode = "0755";
      }
    ];
  };
}
