{ pkgs, ... }:
{
  # Allow unfree + permit insecure Ventoy specifically for ISO builds
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "ventoy-1.1.07"
    ];
  };

  imports = [
    ./_packages.nix
  ];

  # ISO tooling
  environment.systemPackages = with pkgs; [
    ventoy
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDvJx1pyQwQVPPdXlqhJEtUlKyVr4HbZvgbjZ96t75Re"
    ];
  };

  programs.bash.shellAliases = {
    install = "sudo bash -c '$(curl -fsSL https://raw.githubusercontent.com/orther/goodlab/main/install.sh)'";
  };

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  services.openssh = {
    enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
