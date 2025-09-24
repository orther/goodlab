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

  users.users.${config.system.primaryUser}.home = "/Users/${config.system.primaryUser}";

  system = {
    primaryUser = lib.mkDefault "orther";
    startup.chime = false;
    defaults = {
      loginwindow.LoginwindowText = "If lost, contact brandon@orther.dev";
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
      entries = [];
    };
  };

  system.activationScripts.remapCapsLock.text = ''
    echo >&2 "Remapping Caps Lock to Control..."
    sudo -u ${config.system.primaryUser} /usr/bin/hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000E0}]}' || true
  '';

  system.activationScripts.setupWallpaper.text = ''
    echo >&2 "Setting up wallpaper..."
    sudo -u ${config.system.primaryUser} osascript -e 'tell application "Finder" to set desktop picture to POSIX file "/System/Library/Desktop Pictures/Solid Colors/Black.png"'
  '';

  system.stateVersion = 4;
}
