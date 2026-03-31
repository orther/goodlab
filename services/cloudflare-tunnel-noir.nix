# ==============================================================================
# Cloudflare Tunnel for Noir - Media Management & Automation Server
# ==============================================================================
#
# Remotely-managed tunnel — routes configured via Cloudflare Zero Trust dashboard
# and synced by the goodlab-tunnel-management API token.
#
# Published routes (Cloudflare Dashboard):
#   - hass.ryatt.app      → http://localhost:8123
#   - stash.ryatt.app     → http://localhost:9999
#   - sonarr.ryatt.app    → http://localhost:8989
#   - radarr.ryatt.app    → http://localhost:7878
#   - prowlarr.ryatt.app  → http://localhost:9696
#   - nzbget.ryatt.app    → http://localhost:6789
#   - seerr.ryatt.app     → http://localhost:5055
#   - wizarr.ryatt.app    → http://localhost:5690
#   - whisparr.ryatt.app  → http://localhost:6969
#   - tautulli.ryatt.app  → http://localhost:8181
#   - jellystat.ryatt.app → http://localhost:3000
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

  sops.secrets."cloudflare-tunnel-noir-token" = {
    mode = "0444";
  };

  # ==========================================================================
  # Cloudflare Tunnel Service
  # ==========================================================================

  systemd.services."cloudflared-tunnel-noir" = {
    description = "Cloudflare Tunnel for Noir Automation Server";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";

      DynamicUser = true;
      User = "cloudflared";

      ExecStart = pkgs.writeShellScript "cloudflared-tunnel-noir" ''
        exec ${pkgs.cloudflared}/bin/cloudflared tunnel run --token "$(cat ${config.sops.secrets."cloudflare-tunnel-noir-token".path})"
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
