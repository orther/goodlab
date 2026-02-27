{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    package =
      if pkgs.stdenv.isDarwin
      then null
      else pkgs.ghostty;
    settings = {
      # Auto-start tmux; if it exits, fall back to an interactive shell.
      command = "${pkgs.fish}/bin/fish -l -c '${pkgs.tmux}/bin/tmux attach; or ${pkgs.tmux}/bin/tmux; or exec ${pkgs.fish}/bin/fish'";

      "font-family" = "MesloLGS Nerd Font";
      "font-size" =
        if pkgs.stdenv.isDarwin
        then 15
        else 12;
      "window-padding-x" = 5;
      "window-padding-y" = 1;
    };
  };

  catppuccin.ghostty = {
    enable = true;
    flavor = "macchiato";
  };
}
