# ==============================================================================
# Cloudflare Tunnel for Pie - Media Playback Server
# ==============================================================================
#
# Remotely-managed tunnel — routes configured via Cloudflare Zero Trust dashboard
# and synced by the goodlab-tunnel-management API token.
#
# Published routes (Cloudflare Dashboard):
#   - jellyfin.ryatt.app → http://localhost:8096
#   - plex.ryatt.app     → http://localhost:32400
#
# ==============================================================================
{
  config,
  pkgs,
  ...
}: {
  # ==========================================================================
  # SOPS Secret for Tunnel Token
  # ==========================================================================

  sops.secrets."cloudflare-tunnel-pie-token" = {
    mode = "0444";
  };

  # ==========================================================================
  # Cloudflare Tunnel Service
  # ==========================================================================

  systemd.services."cloudflared-tunnel-pie" = {
    description = "Cloudflare Tunnel for Pie Media Server";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";

      DynamicUser = true;
      User = "cloudflared";

      ExecStart = pkgs.writeShellScript "cloudflared-tunnel-pie" ''
        exec ${pkgs.cloudflared}/bin/cloudflared tunnel run --token "$(cat ${config.sops.secrets."cloudflare-tunnel-pie-token".path})"
      '';

      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
    };
  };

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/cloudflared"
    ];
  };
}
