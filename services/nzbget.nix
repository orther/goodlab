# NZBGet - Usenet Downloader
#
# NZBGet provides efficient Usenet downloading with:
# - Multi-server support (Newshosting, Frugal Usenet, Block News)
# - Automatic post-processing (par2 repair, unpack)
# - Category-based download organization (Movies, Series, Music, Software)
# - Web UI on port 6789
#
# Download path strategy:
#   All I/O-heavy operations (downloading, par2 repair, unpacking) happen on
#   local NVMe storage (/var/lib/nzbget/) for speed. Radarr/Sonarr then move
#   completed files to the NAS (/mnt/media/movies, /mnt/media/tv).
#
# SOPS secrets are injected at service start for:
# - Control credentials (web UI login)
# - News server configuration (hosts, usernames, passwords)
#
# Post-installation setup:
#   1. Access NZBGet at http://pie:6789
#   2. Verify news server connections in Settings → News-Servers
#   3. In Radarr: Settings → Download Clients → NZBGet (127.0.0.1:6789, category: Movies)
#   4. In Sonarr: Settings → Download Clients → NZBGet (127.0.0.1:6789, category: Series)
{
  config,
  pkgs,
  lib,
  ...
}: let
  mainDir = "/var/lib/nzbget";
in {
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
      # All working directories on local NVMe for fast I/O.
      # /var/lib/nzbget is already persisted via impermanence.
      # Radarr/Sonarr move completed files to NAS (/mnt/media/).
      MainDir = mainDir;
      DestDir = "${mainDir}/completed";
      InterDir = "${mainDir}/intermediate";
      NzbDir = "${mainDir}/nzb";
      QueueDir = "${mainDir}/queue";
      TempDir = "${mainDir}/tmp";

      # Categories matching existing Debian DockSTARTer setup
      "Category1.Name" = "Movies";
      "Category1.Unpack" = "yes";
      "Category2.Name" = "Series";
      "Category2.Aliases" = "TV";
      "Category2.Unpack" = "yes";
      "Category3.Name" = "Music";
      "Category3.Unpack" = "yes";
      "Category4.Name" = "Software";
      "Category4.Unpack" = "yes";
      "Category5.Name" = "Pr0n";
      "Category5.Unpack" = "yes";

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
  # NZBGet downloads to local NVMe, so it no longer requires the NAS mount.
  # It only needs network for Usenet server connections.
  # Inject SOPS-encrypted credentials into config at service start.

  systemd.services.nzbget = {
    after = ["network-online.target"];
    wants = ["network-online.target"];

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
  # Working Directories
  # ==========================================================================
  # Ensure NZBGet's working directories exist at boot. Containers like
  # Whisparr mount /var/lib/nzbget and expect these paths to exist.

  systemd.tmpfiles.rules = [
    "d ${mainDir}/completed 0750 nzbget nzbget"
    "d ${mainDir}/intermediate 0750 nzbget nzbget"
    "d ${mainDir}/nzb 0750 nzbget nzbget"
    "d ${mainDir}/queue 0750 nzbget nzbget"
    "d ${mainDir}/tmp 0750 nzbget nzbget"
  ];

  # ==========================================================================
  # Firewall
  # ==========================================================================

  networking.firewall.allowedTCPPorts = [6789];

  # ==========================================================================
  # Persistence (for impermanence systems)
  # ==========================================================================
  # NZBGet stores config, state, and active downloads in /var/lib/nzbget.
  # This must be persisted across reboots to keep download queue, history,
  # and in-progress downloads on local NVMe storage.

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
