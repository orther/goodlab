# Overlay to fix sops-nix Go builds in corporate proxy environments
# This adds GOPROXY and GOSUMDB to impureEnvVars for the Go module fetcher
final: prev: {
  # Override sops-install-secrets to allow GOPROXY environment variable
  sops-install-secrets = prev.sops-install-secrets.overrideAttrs (oldAttrs: {
    # Add GOPROXY and GOSUMDB to impureEnvVars for the Go module fetcher
    goModules =
      (oldAttrs.goModules or prev.buildGoModule {
        inherit (oldAttrs) pname version src;
        vendorHash = oldAttrs.vendorHash or null;
      }).overrideAttrs (oldModuleAttrs: {
        impureEnvVars =
          (oldModuleAttrs.impureEnvVars or [])
          ++ [
            "GOPROXY"
            "GOSUMDB"
            "NIX_SSL_CERT_FILE"
            "SSL_CERT_FILE"
          ];
      });
  });
}
