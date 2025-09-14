{config, ...}: {
  sops.secrets = {
    "cloudflare-api-email" = {};
    "cloudflare-api-key" = {};
  };

  # inspo: https://carjorvaz.com/posts/setting-up-wildcard-lets-encrypt-certificates-on-nixos/
  security.acme = {
    acceptTerms = true;
    defaults.email = "brandon@orther.dev";

    certs."orther.dev" = {
      domain = "orther.dev";
      extraDomainNames = ["*.orther.dev"];
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      # inspo: https://go-acme.github.io/lego/dns/cloudflare/
      credentialFiles = {
        "CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets."cloudflare-api-key".path;
      };
      # fix DNS challenge query failing due to using local DNS server
      extraLegoFlags = [ "--dns.resolvers" "1.1.1.1" ];
    };
  };

  users.users.nginx.extraGroups = ["acme"];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  environment.persistence."/nix/persist" = {
    directories = [
      "/var/lib/acme"
    ];
  };
}
