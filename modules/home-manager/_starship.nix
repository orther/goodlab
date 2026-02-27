{...}: {
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      # Catppuccin Macchiato palette colors
      palette = "catppuccin_macchiato";

      format = "$directory$git_branch$git_status$character";
      right_format = "$status$cmd_duration$jobs$direnv$nix_shell$aws$kubernetes$terraform";

      character = {
        success_symbol = "[❯](lavender)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](green)";
      };

      directory = {
        style = "bold blue";
        truncation_length = 3;
        truncation_symbol = "…/";
      };

      git_branch = {
        style = "bold mauve";
        format = "[$symbol$branch(:$remote_branch)]($style) ";
      };

      git_status = {
        style = "bold red";
      };

      cmd_duration = {
        min_time = 2000;
        style = "bold yellow";
        format = "[$duration]($style) ";
      };

      status = {
        disabled = false;
        format = "[$status]($style) ";
        style = "bold red";
      };

      jobs = {
        style = "bold blue";
      };

      nix_shell = {
        format = "[$symbol$state( \\($name\\))]($style) ";
        symbol = "❄️ ";
        style = "bold blue";
      };

      direnv = {
        disabled = false;
        format = "[$symbol$loaded/$allowed]($style) ";
        style = "bold green";
      };

      aws = {
        style = "bold peach";
        format = "[$symbol($profile)(\\($region\\))]($style) ";
      };

      kubernetes = {
        disabled = false;
        style = "bold blue";
        format = "[$symbol$context(\\($namespace\\))]($style) ";
      };

      terraform = {
        style = "bold lavender";
      };

      palettes.catppuccin_macchiato = {
        rosewater = "#f4dbd6";
        flamingo = "#f0c6c6";
        pink = "#f5bde6";
        mauve = "#c6a0f6";
        red = "#ed8796";
        maroon = "#ee99a0";
        peach = "#f5a97f";
        yellow = "#eed49f";
        green = "#a6da95";
        teal = "#8bd5ca";
        sky = "#91d7e3";
        sapphire = "#7dc4e4";
        blue = "#8aadf4";
        lavender = "#b7bdf8";
        text = "#cad3f5";
        subtext1 = "#b8c0e0";
        subtext0 = "#a5adcb";
        overlay2 = "#939ab7";
        overlay1 = "#8087a2";
        overlay0 = "#6e738d";
        surface2 = "#5b6078";
        surface1 = "#494d64";
        surface0 = "#363a4f";
        base = "#24273a";
        mantle = "#1e2030";
        crust = "#181926";
      };
    };
  };
}
