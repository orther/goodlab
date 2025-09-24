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
      export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
      export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
      export XDG_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"
      export DOOMLOCALDIR="$XDG_DATA_HOME/doom"
      export DOOMDATA="$XDG_DATA_HOME/doom/data"
      export DOOMCACHE="$XDG_CACHE_HOME/doom"
      export DOOMSTATE="$XDG_STATE_HOME/doom"
      export PATH="${pkgs.emacs}/bin:${pkgs.git}/bin:$PATH"
      "$HOME/.config/emacs/bin/doom" sync || true
    fi
  '';
}
