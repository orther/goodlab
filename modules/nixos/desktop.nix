{pkgs, ...}: {
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  services.udev.packages = with pkgs; [gnome.gnome-settings-daemon];

  programs._1password.enable = true;
  programs._1password-gui.enable = true;

  environment.persistence."/nix/persist" = {
    directories = [
      "/etc/NetworkManager/system-connections"
    ];

    users."orther" = {
      directories = [
        "Desktop"
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Videos"
        "git"

        ".cache"
        ".config"
        ".mozilla"
        ".vscode"
        ".local"
        {
          directory = ".gnupg";
          mode = "0700";
        }
        {
          directory = ".ssh";
          mode = "0700";
        }
      ];
      files = [
        ".zsh_history"
      ];
    };
  };
}
