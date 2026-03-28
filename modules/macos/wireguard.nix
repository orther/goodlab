{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.wireguard;
in {
  options.local.wireguard = {
    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          address = lib.mkOption {
            type = lib.types.str;
            description = "Interface address with CIDR (e.g. 10.100.0.2/24)";
          };

          privateKeySecret = lib.mkOption {
            type = lib.types.str;
            description = "Name of the SOPS secret containing the private key";
          };

          peers = lib.mkOption {
            type = lib.types.listOf (lib.types.submodule {
              options = {
                publicKey = lib.mkOption {
                  type = lib.types.str;
                  description = "Peer public key";
                };
                endpoint = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Peer endpoint (host:port)";
                };
                allowedIPs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  description = "Allowed IP ranges for this peer";
                };
                persistentKeepalive = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "Persistent keepalive interval in seconds";
                };
              };
            });
            default = [];
            description = "WireGuard peers";
          };
        };
      });
      default = {};
      description = "WireGuard interface definitions";
    };
  };

  config = lib.mkIf (cfg.interfaces != {}) {
    environment.systemPackages = [
      pkgs.wireguard-tools
      pkgs.wireguard-go
    ];

    sops.secrets = lib.mapAttrs' (_name: iface:
      lib.nameValuePair iface.privateKeySecret {})
    cfg.interfaces;

    # Generate wg-quick configs at activation time from SOPS-decrypted keys
    system.activationScripts.setupWireguard.text = let
      genPeer = peer:
        ''
          [Peer]
          PublicKey = ${peer.publicKey}
        ''
        + lib.optionalString (peer.endpoint != null) ''
          Endpoint = ${peer.endpoint}
        ''
        + ''
          AllowedIPs = ${lib.concatStringsSep ", " peer.allowedIPs}
        ''
        + lib.optionalString (peer.persistentKeepalive != null) ''
          PersistentKeepalive = ${toString peer.persistentKeepalive}
        '';

      genConfig = name: iface: ''
        echo >&2 "Generating WireGuard config for ${name}..."
        mkdir -p /etc/wireguard
        chmod 700 /etc/wireguard

        PRIVKEY=$(cat ${config.sops.secrets.${iface.privateKeySecret}.path})
        cat > /etc/wireguard/${name}.conf << 'WGEOF'
        [Interface]
        PrivateKey = PRIVKEY_PLACEHOLDER
        Address = ${iface.address}

        ${lib.concatMapStringsSep "\n" genPeer iface.peers}
        WGEOF

        # Substitute the private key (avoids key in Nix store)
        sed -i "" "s|PRIVKEY_PLACEHOLDER|$PRIVKEY|" /etc/wireguard/${name}.conf
        chmod 600 /etc/wireguard/${name}.conf
      '';
    in
      lib.concatStringsSep "\n" (lib.mapAttrsToList genConfig cfg.interfaces);
  };
}
