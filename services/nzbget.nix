# NZBGet - Usenet Downloader
#
# NZBGet provides efficient Usenet downloading with:
# - Multi-server support (Newshosting, Frugal Usenet, Block News)
# - Automatic post-processing (par2 repair, unpack)
# - Category-based download organization (Movies, Series, Music, Software)
# - Web UI on port 6789
#
# SOPS secrets are injected at service start for:
# - Control credentials (web UI login)
# - News server configuration (hosts, usernames, passwords)
#
# Post-installation setup:
#   1. Access NZBGet at http://pie:6789
#   2. Verify news server connections in Settings → News-Servers
#   3. Configure integration with Sonarr/Radarr download clients
{
  config,
  pkgs,
  lib,
  ...
}: {
  # ==========================================================================
  # SOPS Secrets
  # ==========================================================================

  sops.secrets."nzbget/control-username" = {
    owner = "nzbget";
    mode = "0400";
  };
  sops.secrets."nzbget/control-password" = {
    owner = "nzbget";
    mode = "0400";
  };
  sops.secrets."nzbget/server-config" = {
    owner = "nzbget";
    mode = "0400";
  };

  # ==========================================================================
  # NZBGet Service
  # ==========================================================================

  services.nzbget = {
    enable = true;
    user = "nzbget";
    group = "nzbget";
    settings = {
      # Paths on NAS
      MainDir = "/mnt/docker-data/usenet";
      DestDir = "/mnt/docker-data/usenet/completed";
      InterDir = "/mnt/docker-data/usenet/intermediate";
      NzbDir = "/mnt/docker-data/usenet/nzb";
      QueueDir = "/mnt/docker-data/usenet/queue";
      TempDir = "/mnt/docker-data/usenet/tmp";

      # Categories matching existing setup
      "Category1.Name" = "Movies";
      "Category1.Unpack" = "yes";
      "Category2.Name" = "Series";
      "Category2.Aliases" = "TV";
      "Category2.Unpack" = "yes";
      "Category3.Name" = "Music";
      "Category3.Unpack" = "yes";
      "Category4.Name" = "Software";
      "Category4.Unpack" = "yes";

      AppendCategoryDir = "no";

      # Network
      ControlIP = "0.0.0.0";
      ControlPort = 6789;

      # Performance
      ArticleCache = 50;
      DirectWrite = "yes";
      WriteBuffer = 4096;
      FileNaming = "auto";

      # Post-processing
      ParCheck = "auto";
      ParRepair = "yes";
      ParScan = "limited";
      ParQuick = "yes";
      DirectUnpack = "yes";
      Unpack = "yes";
      CrcCheck = "yes";
      HealthCheck = "delete";

      # Logging (mkForce overrides NixOS module default of "none")
      WriteLog = lib.mkForce "rotate";
      RotateLog = 3;

      # Other settings
      DiskSpace = 250;
      KeepHistory = 30;
      ArticleRetries = 3;
      DownloadRate = 0;
      DupeCheck = "no";
      ContinuePartial = "no";
      ReorderFiles = "yes";
      PostStrategy = "balanced";
    };
  };

  # ==========================================================================
  # Systemd Service Adjustments
  # ==========================================================================
  # Ensure NZBGet waits for network and NAS mount before starting.
  # Inject SOPS-encrypted credentials into config at service start.
  # Note: hyphen in path becomes \x2d in systemd unit names

  systemd.services.nzbget = {
    after = ["network-online.target" "mnt-docker\\x2ddata.mount"];
    wants = ["network-online.target"];
    requires = ["mnt-docker\\x2ddata.mount"];

    preStart = lib.mkAfter ''
      CONFIG="/var/lib/nzbget/nzbget.conf"
      if [ -f "$CONFIG" ]; then
        # Strip existing server and control credential lines
        ${pkgs.gnused}/bin/sed -i '/^Server[0-9]\+\./d' "$CONFIG"
        ${pkgs.gnused}/bin/sed -i '/^ControlUsername=/d' "$CONFIG"
        ${pkgs.gnused}/bin/sed -i '/^ControlPassword=/d' "$CONFIG"
        ${pkgs.gnused}/bin/sed -i '/^AddUsername=/d' "$CONFIG"
        ${pkgs.gnused}/bin/sed -i '/^AddPassword=/d' "$CONFIG"
      fi

      # Inject control credentials
      echo "ControlUsername=$(cat ${config.sops.secrets."nzbget/control-username".path})" >> "$CONFIG"
      echo "ControlPassword=$(cat ${config.sops.secrets."nzbget/control-password".path})" >> "$CONFIG"

      # Inject news server config block
      cat ${config.sops.secrets."nzbget/server-config".path} >> "$CONFIG"
    '';
  };

  # ==========================================================================
  # Firewall
  # ==========================================================================

  networking.firewall.allowedTCPPorts = [6789];

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================
  # NZBGet stores its configuration and state in /var/lib/nzbget.
  # This must be persisted across reboots to keep download queue and history.

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/nzbget";
        user = "nzbget";
        group = "nzbget";
        mode = "0750";
      }
    ];
  };
}
