{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-doom-emacs.hmModule ];

  programs.doom-emacs = {
    enable = true;
    # Use upstream Emacs from nixpkgs; swap for emacsMacport if preferred.
    emacsPackage = pkgs.emacs;
    # Avoid nix-community/emacs-overlay to sidestep overrideScope' mismatch
    # on some nixpkgs revisions.
    useEmacsOverlay = false;
    # Provide a minimal Doom config stored in-repo
    doomPrivateDir = ./doom.d;
  };
}
