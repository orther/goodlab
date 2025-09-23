{ inputs, pkgs, lib, ... }:
{
  programs.emacs = {
    enable = true;
    package = if pkgs.stdenv.isDarwin then pkgs.emacsMacport else pkgs.emacs;
  };

  # Link Doom core and your Doom config into $HOME
  home.file.".config/emacs".source = inputs.doom-emacs;
  home.file.".config/doom".source = ./doom.d;

  # Ensure `doom` CLI is on PATH for activation scripts
  home.sessionPath = lib.mkIf pkgs.stdenv.isDarwin (lib.mkAfter [ "$HOME/.config/emacs/bin" ]);

  # Sync Doom packages after HM writes files (best-effort)
  home.activation.doomSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "$HOME/.config/emacs/bin/doom" ]; then
      "$HOME/.config/emacs/bin/doom" -y sync || true
    fi
  '';
}
