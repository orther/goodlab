{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.wireguard;

  genPeerSection = peer:
    "[Peer]\n"
    + "PublicKey = ${peer.publicKey}\n"
    + lib.optionalString (peer.endpoint != null) "Endpoint = ${peer.endpoint}\n"
    + "AllowedIPs = ${lib.concatStringsSep ", " peer.allowedIPs}\n"
    + lib.optionalString (peer.persistentKeepalive != null) "PersistentKeepalive = ${toString peer.persistentKeepalive}\n";

  genConfigText = name: iface: ''
    [Interface]
    Address = ${iface.address}
    PostUp = wg set %i private-key ${config.sops.secrets.${iface.privateKeySecret}.path}

    ${lib.concatMapStringsSep "\n" genPeerSection iface.peers}
  '';
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

    environment.etc = lib.mapAttrs' (name: iface:
      lib.nameValuePair "wireguard/${name}.conf" {
        text = genConfigText name iface;
      })
    cfg.interfaces;
  };
}
