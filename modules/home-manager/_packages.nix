{
  pkgs,
  osConfig,
  ...
}: let
  base = with pkgs; [
    asciiquarium
    bat
    bind
    btop
    cbonsai
    clolcat
    cmatrix
    croc
    dust
    dua
    duf
    figlet
    fortune-kind
    gallery-dl
    gdu
    genact
    gti
    htop
    hyperfine
    imagemagick
    kopia
    neo-cowsay
    pandoc
    pipes-rs
    poppler-utils
    qrencode
    tree
    yt-dlp
  ];
  # Below packages are for development and therefore excluded from servers
  dev = with pkgs; (
    if
      builtins.substring 0 3 osConfig.networking.hostName
      != "svr"
      && builtins.substring 0 2 osConfig.networking.hostName != "vm"
    then [
      alejandra
      asdf-vm
      bun
      claude-code
      doppler
      flyctl
      just
      nil
      nixfmt-rfc-style
      nixos-rebuild # need for macOS
      nodejs
      nodePackages_latest.eas-cli
      nodePackages.typescript
      nodePackages.typescript-language-server
      sops
      statix
      stripe-cli
      wrangler
      zola
    ]
    else []
  );
  combined = base ++ dev;
  combinedFiltered =
    if (osConfig.local.corporateNetwork or false)
    then builtins.filter (p: p != pkgs.wrangler) combined
    else combined;
in {
  home.packages = combinedFiltered;
}
