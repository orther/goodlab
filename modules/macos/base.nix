{
  config,
  lib,
  ...
}: {
  imports = [
    ./_dock.nix
    ./_packages.nix
  ];

  nix = {
    enable = false; # Disable nix-darwin's Nix management (using Determinate Nix)
    # NOTE: Settings below are NOT applied when enable = false
    # For Determinate Nix, use scripts/setup-nix-trusted-users.sh to configure trusted-users
    # See docs/NIX_TRUSTED_USERS.md for details
    settings = {
      experimental-features = "nix-command flakes";
      trusted-users = [
        "root"
        "@admin"
      ];
    };
  };

  programs.zsh.enable = true;
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  services = {
    tailscale.enable = true;
  };

  users.users.${config.system.primaryUser}.home = "/Users/${config.system.primaryUser}";

  system = {
    primaryUser = lib.mkDefault "orther";
    startup.chime = false;
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
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
        Show24Hour = false;
      };

      NSGlobalDomain = {
        AppleICUForce24HourTime = false;
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
        {path = "/Applications/Google Chrome.app";}
        {path = "/Applications/Slack.app";}
        {path = "/System/Applications/System Settings.app";}
        {path = "/System/Applications/Launchpad.app";}
      ];
    };
  };

  system.activationScripts.setupTextReplacements.text = ''
    echo >&2 "Configuring text replacements..."
    sudo -u ${config.system.primaryUser} /usr/bin/defaults write -g NSUserDictionaryReplacementItems -array \
      '{on = 1; replace = "@@nb"; with = "Brandon.Orther@nationsbenefits.com";}' \
      '{on = 1; replace = "@@o"; with = "brandon@orther.dev";}' \
      '{on = 1; replace = "@@c"; with = "brandon.orther@carecar.co";}'
    sudo -u ${config.system.primaryUser} /usr/bin/killall cfprefsd || true
  '';

  system.activationScripts.setupWallpaper.text = ''
    echo >&2 "Setting up wallpaper..."
    sudo -u ${config.system.primaryUser} osascript -e 'tell application "Finder" to set desktop picture to POSIX file "/System/Library/Desktop Pictures/Solid Colors/Black.png"'
  '';

  system.stateVersion = 4;
}
