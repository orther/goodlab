{ config, pkgs, lib, ... }: {
  imports = [
    ./_dock.nix
    ./_packages.nix
  ];

  nix = {
    enable = false; # Disable nix-darwin's Nix management (using Determinate Nix)
    settings = {
      experimental-features = "nix-command flakes";
      trusted-users = [
        "root"
        "@admin"
      ];
    };
  };

  programs.zsh.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  services = {
    tailscale.enable = true;
  };

  # Mark this host as being on a corporate network with strict TLS interception.
  # Used by HM modules to avoid packages that fetch from npm at build time (e.g., wrangler).
  local.corporateNetwork = true;

  users.users.${config.system.primaryUser}.home = "/Users/${config.system.primaryUser}";

  system = {
    primaryUser = lib.mkDefault "brandon.orther";
    startup.chime = false;
    defaults = {
      loginwindow.LoginwindowText = "If lost, contact brandon.orther@nationsbenefits.com";
      # screencapture.location = "~/OneDrive/30-39 Hobbies/34 Photos/34.01 Screenshots";

      dock = {
        autohide = true;
        mru-spaces = false;
        tilesize = 96;
        wvous-br-corner = 4;
        wvous-bl-corner = 11;
        wvous-tr-corner = 5;
      };

      finder = {
        AppleShowAllExtensions = true;
        FXPreferredViewStyle = "clmv";
      };

      menuExtraClock = {
        ShowSeconds = true;
        Show24Hour = true;
        ShowAMPM = false;
      };

      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        # inspo: https://apple.stackexchange.com/questions/261163/default-value-for-nsglobaldomain-initialkeyrepeat
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };
    };
  };

  local = {
    dock = {
      enable = true;
      entries = [
        {path = "/Applications/1Password.app";}
        {path = "/System/Applications/System Settings.app";}
      ];
    };
  };

  system.activationScripts.setupWallpaper.text = ''
    echo >&2 "Setting up wallpaper..."
    sudo -u ${config.system.primaryUser} osascript -e 'tell application "Finder" to set desktop picture to POSIX file "/System/Library/Desktop Pictures/Solid Colors/Black.png"'
  '';

  system.stateVersion = 4;
}
