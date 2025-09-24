{
  config,
  inputs,
  lib,
  ...
}:
let
  homebrewInstalled =
    builtins.pathExists "/opt/homebrew/bin/brew"
    || builtins.pathExists "/usr/local/bin/brew";
in {
  # Temporarily disable nix-homebrew to avoid conflicts with existing installation
  # imports = [
  #   inputs.nix-homebrew.darwinModules.nix-homebrew
  # ];

  # nix-homebrew = {
  #   enable = true;
  #   # NOTE: Disabled this until I migrate M1 Ultra to use Nix
  #   # enableRosetta = true;
  #   enableRosetta = false;
  #   user = "orther";
  #   mutableTaps = true; # Allow existing taps to coexist
  #   taps = {
  #     "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
  #     "homebrew/homebrew-cask" = inputs.homebrew-cask;
  #     "homebrew/homebrew-core" = inputs.homebrew-core;
  #   };
  #   autoMigrate = true;
  # };

  config = lib.mkIf homebrewInstalled {
    homebrew = {
      enable = true;
      global = {
        autoUpdate = true;
      };
      onActivation = {
        autoUpdate = false;
        upgrade = false;
        cleanup = "zap";
      };
      brews = [
        "codex"
        "trash"
      ];
      taps = [
        "homebrew/bundle"
        "homebrew/cask"
        "homebrew/core"
      ];
      casks = [
        "1password"
        "alacritty"
        # "betterdisplay"
        # "caffeine"
        # "discord"
        # "dropbox"
        # "exifcleaner"
        # "figma-agent"
        # "firefox"
        # "google-chrome"
        # "handbrake"
        # "linearmouse"
        # "obsidian"
        "rar"
        "raycast"
        # "screen-studio"
        # "spotify"
        "the-unarchiver"
        "visual-studio-code"
        "vlc"
      ];
      masApps = {
        "1Password for Safari" = 1569813296;
        # "Infuse" = 1136220934;
        # "Messenger" = 1480068668;
        # "Microsoft Excel" = 462058435;
        # "Microsoft PowerPoint" = 462062816;
        # "Microsoft Remote Desktop" = 1295203466;
        # "Microsoft Word" = 462054704;
        # "OneDrive" = 823766827;
        # "Tailscale" = 1475387142;
      };
    };
  };
}
