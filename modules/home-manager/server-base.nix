# Minimal home-manager configuration for servers
#
# This is a lighter version of base.nix that excludes heavy development
# tools (wrangler, nixvim, etc.) that aren't needed on headless servers.
# Use this for media servers, NAS boxes, and other infrastructure machines.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./_zsh.nix
    ./tmux.nix
    ./neovim.nix
  ];

  home = {
    homeDirectory = lib.mkMerge [
      (lib.mkIf pkgs.stdenv.isLinux "/home/${config.home.username}")
      (lib.mkIf pkgs.stdenv.isDarwin "/Users/${config.home.username}")
    ];
    stateVersion = "23.11";
    sessionVariables = {
      SHELL = "${pkgs.zsh}/bin/zsh";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
      SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
    };

    # Minimal packages for server administration
    packages = with pkgs; [
      # Core utilities
      curl
      wget
      htop
      btop
      ripgrep
      fd
      jq
      tree
      unzip

      # Nix tools
      alejandra
      nil

      # System tools
      pciutils
      usbutils
      lsof
    ];
  };

  catppuccin = {
    flavor = "macchiato";
    accent = "lavender";
  };

  programs = {
    git.enable = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    lsd = {
      enable = true;
      enableZshIntegration = true;
    };
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
    fastfetch.enable = true;
  };

  systemd.user.startServices = "sd-switch";
}
