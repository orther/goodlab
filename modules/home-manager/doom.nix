{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-doom-emacs.hmModule ];

  programs.doom-emacs = {
    enable = true;
    # Use upstream Emacs from nixpkgs; swap for emacsMacport if preferred.
    emacsPackage = pkgs.emacs;
    # Provide a minimal Doom config stored in-repo
    doomPrivateDir = ./doom.d;
  };
}
