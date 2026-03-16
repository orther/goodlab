# ==============================================================================
# UniFi Network Server - Zinc (Condo)
# ==============================================================================
#
# UniFi Network Application via Podman containers.
# Uses linuxserver/unifi-network-application (app) + mongo:7.0 (database).
#
# The native services.unifi NixOS module is broken with pkgs.unifi 10.1.x:
# that version bundles its own MongoDB binary which segfaults on NixOS due to
# the non-FHS filesystem layout. Containers work because they provide their
# own FHS environment.
#
# Access:
#   - Local:     https://192.168.1.158:8443
#   - Tailscale: https://<zinc-tailscale-ip>:8443
#
# Initial setup (10.1.x):
#   Ubiquiti requires a cloud account login for first-time setup.
#   A local admin account can be created after initial configuration.
#
# Device adoption:
#   Devices on 192.168.1.x are auto-discovered via UDP 10001.
#   For devices on other subnets, set inform URL to:
#   http://192.168.1.158:8080/inform
#
# ==============================================================================
{pkgs, ...}: let
  # MongoDB credentials — internal only, not exposed outside the container network.
  # The unifi container network is not accessible from the host or LAN directly.
  mongoPassword = "unifi-internal";
in {
  # ==========================================================================
  # Podman
  # ==========================================================================

  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
  };

  # ==========================================================================
  # MongoDB init script
  # ==========================================================================
  # Written to /etc (persists via NixOS activation) and mounted read-only
  # into the mongo container. MongoDB only runs initdb scripts when the data
  # directory is empty (i.e., first boot), so this is safe to leave in place.

  environment.etc."unifi-mongo-init.js".text = ''
    db.getSiblingDB("unifi").createUser({
      user: "unifi",
      pwd: "${mongoPassword}",
      roles: [{ role: "dbOwner", db: "unifi" }]
    });
    db.getSiblingDB("unifi_stat").createUser({
      user: "unifi",
      pwd: "${mongoPassword}",
      roles: [{ role: "dbOwner", db: "unifi_stat" }]
    });
  '';

  # ==========================================================================
  # Podman network
  # ==========================================================================
  # Creates the 'unifi-net' network before containers start.
  # The unifi app container connects to MongoDB by DNS name 'unifi-db'.

  systemd.services."podman-create-unifi-net" = {
    description = "Create podman network for unifi stack";
    after = ["network-online.target" "nss-lookup.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "create-unifi-net" ''
        ${pkgs.podman}/bin/podman network exists unifi-net || \
          ${pkgs.podman}/bin/podman network create unifi-net
      '';
    };
  };

  # Ensure containers start after network is created
  systemd.services."podman-unifi-db" = {
    after = ["podman-create-unifi-net.service"];
    requires = ["podman-create-unifi-net.service"];
  };
  systemd.services."podman-unifi" = {
    after = ["podman-unifi-db.service"];
  };

  # ==========================================================================
  # Containers
  # ==========================================================================

  virtualisation.oci-containers = {
    backend = "podman";

    containers = {
      # MongoDB 4.4 — required for the J4125 (Gemini Lake, no AVX support).
      # MongoDB 5.0+ require AVX; 4.4 only needs SSE4.2 which J4125 supports.
      # UniFi Network Application 8.x still supports MongoDB 4.4.
      "unifi-db" = {
        image = "docker.io/mongo:4.4";
        extraOptions = [
          "--network=unifi-net"
          "--network-alias=unifi-db"
        ];
        # Limit WiredTiger cache for a homelab mini PC sharing resources with HA
        cmd = ["--wiredTigerCacheSizeGB" "0.25"];
        volumes = [
          "/nix/persist/var/lib/unifi/db:/data/db"
          "/etc/unifi-mongo-init.js:/docker-entrypoint-initdb.d/init.js:ro"
        ];
      };

      # UniFi Network Application
      "unifi" = {
        image = "lscr.io/linuxserver/unifi-network-application:latest";
        extraOptions = ["--network=unifi-net"];
        ports = [
          "8443:8443"
          "8080:8080"
          "3478:3478/udp"
          "10001:10001/udp"
        ];
        environment = {
          PUID = "0";
          PGID = "0";
          TZ = "America/Los_Angeles";
          MONGO_USER = "unifi";
          MONGO_PASS = mongoPassword;
          MONGO_HOST = "unifi-db";
          MONGO_PORT = "27017";
          MONGO_DBNAME = "unifi";
          MEM_LIMIT = "1024";
          MEM_STARTUP = "512";
        };
        volumes = ["/nix/persist/var/lib/unifi/config:/config"];
      };
    };
  };

  # ==========================================================================
  # Firewall
  # ==========================================================================

  networking.firewall = {
    allowedTCPPorts = [8443 8080];
    allowedUDPPorts = [3478 10001];
  };

  # ==========================================================================
  # Persistence (Impermanence)
  # ==========================================================================
  # Ensure subdirectories exist before containers start.
  # Podman bind-mount volumes require the host paths to already exist.

  systemd.tmpfiles.rules = [
    "d /nix/persist/var/lib/unifi/db 0755 root root - -"
    "d /nix/persist/var/lib/unifi/config 0755 root root - -"
    "d /nix/persist/var/lib/containers 0755 root root - -"
  ];

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/unifi";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # Persist container images so pulls only happen on first boot or image updates,
      # not on every reboot. Eliminates the boot-time DNS race where containers try
      # to pull before DHCP delivers nameservers to systemd-resolved.
      {
        directory = "/var/lib/containers";
        user = "root";
        group = "root";
        mode = "0755";
      }
    ];
  };
}
