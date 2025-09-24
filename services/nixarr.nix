{ pkgs, ... }: {
  imports = [
    ./_acme.nix
    ./_nginx.nix
    ./_cloudflared.nix
  ];

  # temp
  # inspo: https://discourse.nixos.org/t/solved-sonarr-is-broken-in-24-11-unstable-aka-how-the-hell-do-i-use-nixpkgs-config-permittedinsecurepackages/56828/2
  nixpkgs.config.permittedInsecurePackages = [
    "aspnetcore-runtime-6.0.36"
    "aspnetcore-runtime-wrapped-6.0.36"
    "dotnet-sdk-6.0.428"
    "dotnet-sdk-wrapped-6.0.428"
  ];

  ##sops = {
  ##  secrets = {
  ##    "kopia-repository-token" = {};
  ##    "wg.conf" = {
  ##      format = "binary";
  ##      sopsFile = ./../secrets/wg.conf;
  ##    };
  ##  };
  ##};

  nixarr = {
    enable = true;
    mediaDir = "/fun";
    stateDir = "/var/lib/nixarr";

    jellyfin.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    sonarr.enable = true;

    transmission = {
      enable = true;
      package = pkgs.transmission_4;
      # todo: figure out how to update this easier
      peerPort = 46634;
      ##vpn.enable = true;
      extraSettings = {
        incomplete-dir-enabled = false;
        speed-limit-up = 500;
        speed-limit-up-enabled = true;
        rpc-authentication-required = true;
        rpc-username = "orther";
        rpc-whitelist-enabled = false;
        # todo: figure out how to integrate rpc-password into sops-nix
        rpc-password = "{7d827abfb09b77e45fe9e72d97956ab8fb53acafoPNV1MpJ";
      };
    };

    vpn = {
      ## TODO: enable vpn if it makes sense
      enable = false;
      ##enable = true;
      ##wgConf = config.sops.secrets."wg.conf".path;
    };
  };

  ## TODO: enable hardware once I nail down what noir server supports
  ##nixpkgs.config.packageOverrides = pkgs: {
  ##  vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
  ##};

  ##hardware.opengl = {
  ##  enable = true;
  ##  extraPackages = with pkgs; [
  ##    intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
  ##    intel-media-driver
  ##    libvdpau-va-gl
  ##    vaapiIntel
  ##    vaapiVdpau
  ##  ];
  ##};

  ##environment.systemPackages = with pkgs; [
  ##  # To enable `intel_gpu_top`
  ##  intel-gpu-tools
  ##  # because nixarr does not include it by default
  ##  wireguard-tools
  ##];

  services.nginx = {
    virtualHosts = {
      "watch.orther.dev" = {
        forceSSL = true;
        useACMEHost = "orther.dev";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://127.0.0.1:8096";
        };
      };

      "prowlarr.orther.dev" = {
        forceSSL = true;
        useACMEHost = "orther.dev";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://127.0.0.1:9696";
        };
      };

      "radarr.orther.dev" = {
        forceSSL = true;
        useACMEHost = "orther.dev";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://127.0.0.1:7878";
        };
      };

      "sonarr.orther.dev" = {
        forceSSL = true;
        useACMEHost = "orther.dev";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://127.0.0.1:8989";
        };
      };

      "transmission.orther.dev" = {
        forceSSL = true;
        useACMEHost = "orther.dev";
        locations."/" = {
          proxyPass = "http://127.0.0.1:9091";
        };
      };
    };
  };

  systemd = {
    tmpfiles.rules = ["d /var/lib/nixarr 0755 root root"];

    ## TODO: enable backing up Nixarr
    ##services = {
    ##  "backup-nixarr" = {
    ##    description = "Backup Nixarr installation with Kopia";
    ##    wantedBy = ["default.target"];
    ##    serviceConfig = {
    ##      User = "root";
    ##      ExecStartPre = "${pkgs.kopia}/bin/kopia repository connect from-config --token-file ${config.sops.secrets."kopia-repository-token".path}";
    ##      ExecStart = "${pkgs.kopia}/bin/kopia snapshot create /var/lib/nixarr";
    ##      ExecStartPost = "${pkgs.kopia}/bin/kopia repository disconnect";
    ##    };
    ##  };
    ##};

    ##timers = {
    ##  "backup-nixarr" = {
    ##    description = "Backup Nixarr installation with Kopia";
    ##    wantedBy = ["timers.target"];
    ##    timerConfig = {
    ##      OnCalendar = "*-*-* 4:00:00";
    ##      RandomizedDelaySec = "1h";
    ##    };
    ##  };
    ##};
  };

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/nixarr"
    ];
  };
}
