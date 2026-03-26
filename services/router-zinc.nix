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
{lib, ...}: {
  # ==========================================================================
  # IP forwarding + kernel hardening
  # ==========================================================================

  boot.kernel.sysctl = {
    # Routing
    "net.ipv4.ip_forward" = 1;

    # SYN flood protection
    "net.ipv4.tcp_syncookies" = 1;

    # Disable ICMP redirects (router should never accept or send these)
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;

    # Disable source-routed packets (used in IP spoofing attacks)
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;

    # Log packets with impossible source addresses
    "net.ipv4.conf.all.log_martians" = 1;

    # Ignore bogus ICMP error responses
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # Strict reverse-path filtering (anti-spoofing)
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
  };

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
    # Port 3 (MAC c6:7f) is an onboard NIC that enumerates as "eno1" — stable
    # name comes from the kernel, no link file needed. Reserved as spare LAN port.
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
      enp1s0.useDHCP = true; # WAN — DHCP lease from ISP modem
      enp2s0.ipv4.addresses = [{
        address = "10.0.0.1";
        prefixLength = 24;
      }];
      enp4s0.ipv4.addresses = [{
        address = "192.168.254.1";
        prefixLength = 24;
      }];
    };

    # NAT — masquerade LAN traffic behind the WAN IP.
    # Note: networking.nftables is NOT enabled; NixOS defaults to iptables.
    # networking.nat uses iptables MASQUERADE rules on externalInterface.
    nat = {
      enable = true;
      externalInterface = "enp1s0";
      internalInterfaces = ["enp2s0"];
    };

    # Firewall — LAN-side DHCP and DNS
    firewall = {
      # Use loose rpfilter — Tailscale's policy routing rules cause strict
      # rpfilter (in the mangle table) to drop legitimate LAN traffic because
      # the "best" return path goes through Tailscale's routing table, not
      # directly back through enp2s0.
      checkReversePath = "loose";
      interfaces.enp2s0 = {
        allowedUDPPorts = [53 67];
        allowedTCPPorts = [53];
      };
      # enp4s0 (192.168.254.0/24) is intentionally isolated — no NAT, no DNS/DHCP.
      # Management subnet is for direct access to zinc only; LAN devices won't be
      # on this interface in normal operation.

      # IPv6 forward-chain lockdown — zinc receives a delegated /64 from Spectrum
      # via DHCPv6-PD but does not route IPv6 traffic today. The ip6tables FORWARD
      # chain defaults to ACCEPT with no rules — lock it down.
      extraCommands = ''
        ip6tables -P FORWARD DROP
      '';
      extraStopCommands = ''
        ip6tables -P FORWARD ACCEPT
      '';
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
        id = 1;
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
  #
  # bind-interfaces = true requires enp2s0 to exist before dnsmasq starts.
  # systemd-networkd-wait-online is disabled on zinc, so we explicitly order
  # dnsmasq after the enp2s0 device unit to avoid a startup race.

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "enp2s0";
      bind-interfaces = true;
      # Don't read /etc/resolv.conf — it points to systemd-resolved stub
      no-resolv = true;
      server = ["127.0.0.1#5053"]; # dnscrypt-proxy (encrypted upstream)
      cache-size = 1000;

      # Security hardening
      stop-dns-rebind = true;    # Reject upstream answers containing private IPs
      rebind-localhost-ok = true; # Allow 127.x responses (some services need this)
      domain-needed = true;       # Don't forward bare names (e.g. "printer") upstream
      bogus-priv = true;          # Don't forward reverse lookups for private ranges
      dns-forward-max = 150;      # Cap concurrent upstream queries (DoS protection)
    };
  };

  # The NixOS kea module sets DynamicUser = true, which puts state in
  # /var/lib/private/kea and makes /var/lib/kea a symlink. This conflicts
  # with impermanence's bind mount at /var/lib/kea ("Device or resource busy").
  # Force DynamicUser off so kea runs as the static kea user and our
  # impermanence setup owns /var/lib/kea directly.
  systemd.services.kea-dhcp4-server = {
    after = ["sys-subsystem-net-devices-enp2s0.device"];
    requires = ["sys-subsystem-net-devices-enp2s0.device"];
  };

  systemd.services.kea-dhcp4-server.serviceConfig.DynamicUser = lib.mkForce false;

  # ==========================================================================
  # Encrypted DNS upstream (dnscrypt-proxy)
  # ==========================================================================
  # Listens on 127.0.0.1:5053. dnsmasq forwards to it instead of plaintext
  # Cloudflare. Encrypts all upstream DNS queries via DoH/DNSCrypt so the ISP
  # cannot snoop on DNS traffic.

  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      listen_addresses = ["127.0.0.1:5053"];
      # Use Cloudflare's encrypted resolvers
      server_names = ["cloudflare" "cloudflare-ipv6"];
      # Require DNSSEC and no-logging from upstream
      require_dnssec = true;
      require_nofilter = true;
      require_nolog = true;
    };
  };

  # Point zinc's own resolver (systemd-resolved) at dnscrypt-proxy too.
  # Without this, zinc itself uses ISP DNS (from DHCP on enp1s0) which returns
  # AAAA records for dual-stack domains. Since zinc has no working IPv6 routing,
  # tools like `ping google.com` hang trying the IPv6 address.
  services.resolved.settings.Resolve.DNS = ["127.0.0.1:5053"];

  # Stop the WAN DHCP client from injecting ISP DNS into systemd-resolved.
  systemd.network.networks."40-enp1s0".dhcpV4Config.UseDNS = false;
  systemd.network.networks."40-enp1s0".dhcpV6Config.UseDNS = false;

  # Ensure dnsmasq starts after dnscrypt-proxy is ready
  systemd.services.dnsmasq = {
    after = ["sys-subsystem-net-devices-enp2s0.device" "dnscrypt-proxy.service"];
    requires = ["sys-subsystem-net-devices-enp2s0.device"];
    wants = ["dnscrypt-proxy.service"];
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
