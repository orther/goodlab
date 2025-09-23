{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-doom-emacs.hmModule ];

  programs.doom-emacs = {
    enable = true;
    # Use upstream Emacs from nixpkgs; swap for emacsMacport if preferred.
    emacsPackage = pkgs.emacs;
  };
}

