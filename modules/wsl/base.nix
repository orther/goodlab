{pkgs, ...}: {
  imports = [
    ./_packages.nix
  ];

  wsl = {
    enable = true;
    defaultUser = "orther";
  };

  nixpkgs.config.allowUnfree = true;
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  users.users.orther = {
    isNormalUser = true;
    description = "orther";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = false;
  time.timeZone = "America/New_York";
  zramSwap.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
