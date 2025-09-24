{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./_packages.nix
    ./_zsh.nix
  ];

  home = {
    # Use the HM user name provided by the host configs; derive home path from it.
    homeDirectory = lib.mkMerge [
      (lib.mkIf pkgs.stdenv.isLinux "/home/${config.home.username}")
      (lib.mkIf pkgs.stdenv.isDarwin "/Users/${config.home.username}")
    ];
    stateVersion = "23.11";
    sessionVariables = lib.mkIf pkgs.stdenv.isDarwin {
      SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
      SSL_CERT_FILE = "/etc/ssl/nix-corporate/ca-bundle.pem";
      REQUESTS_CA_BUNDLE = "/etc/ssl/nix-corporate/ca-bundle.pem";
      ERL_SSL_PATH = "/etc/ssl/nix-corporate";
      ERL_SSL_CERTFILE = "/etc/ssl/nix-corporate/ca-bundle.pem";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
      DOOMLOCALDIR = "$HOME/.local/share/doom";
      DOOMDATA = "$HOME/.local/share/doom/data";
      DOOMCACHE = "$HOME/.cache/doom";
      DOOMSTATE = "$HOME/.local/state/doom";
    };
  };

  programs = {
    git = {
      enable = true;
    };
    ssh.enableDefaultConfig = false;
    helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        theme = "dark_high_contrast";
      };
    };
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    zellij = {
      enable = true;
      settings = {
        theme = "dracula";
      };
    };
    tealdeer = {
      enable = true;
      settings.updates.auto_update = true;
    };
    lsd = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
    fastfetch.enable = true;
  };

  # Nicely reload system units when changing configs
  # Self-note: nix-darwin seems to luckily ignore this setting
  systemd.user.startServices = "sd-switch";
}
