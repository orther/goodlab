{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-doom-emacs.hmModule ];

  programs.doom-emacs = {
    enable = true;
    # Prefer native macOS build on Darwin; fallback to standard Emacs elsewhere.
    emacsPackage = if pkgs.stdenv.isDarwin then pkgs.emacsMacport else pkgs.emacs;
    # Provide a minimal Doom config stored in-repo
    doomPrivateDir = ./doom.d;
  };
}
