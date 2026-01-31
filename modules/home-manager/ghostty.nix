{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty;
    settings = {
      # Auto-start tmux; if it exits, fall back to an interactive shell.
      command = "${pkgs.zsh}/bin/zsh -lc '${pkgs.tmux}/bin/tmux attach || ${pkgs.tmux}/bin/tmux; exec ${pkgs.zsh}/bin/zsh'";

      "font-family" = "MesloLGS Nerd Font";
      "font-size" = if pkgs.stdenv.isDarwin then 15 else 12;
      "window-padding-x" = 5;
      "window-padding-y" = 1;
    };
  };

  catppuccin.ghostty = {
    enable = true;
    flavor = "macchiato";
  };
}
