# Common hardening configuration for Research Relay services
# Applied to both noir (Odoo/PDF-intake) and zinc (BTCPay) hosts
{
  config,
  pkgs,
  lib,
  ...
}: {
  # SSH hardening (builds on base.nix settings)
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "no";
    PasswordAuthentication = lib.mkForce false;
    KbdInteractiveAuthentication = false;
    X11Forwarding = false;
  };

  # fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    jails = {
      sshd = {
        settings = {
          enabled = true;
          filter = "sshd";
          port = "ssh";
          logpath = "/var/log/auth.log";
        };
      };
    };
  };

  # nftables firewall (complementary to base firewall)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22 80 443];
    # Optional: Cloudflare IP allowlist for HTTP/HTTPS
    # extraInputRules = ''
    #   # Cloudflare IPv4 ranges - https://www.cloudflare.com/ips-v4
    #   ip saddr { 173.245.48.0/20, 103.21.244.0/22, 103.22.200.0/22, 103.31.4.0/22, 141.101.64.0/18, 108.162.192.0/18, 190.93.240.0/20, 188.114.96.0/20, 197.234.240.0/22, 198.41.128.0/17, 162.158.0.0/15, 104.16.0.0/13, 104.24.0.0/14, 172.64.0.0/13, 131.0.72.0/22 } tcp dport { 80, 443 } accept
    # '';
  };

  # Nginx hardening (extends _nginx.nix)
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Security headers for all vhosts
    appendHttpConfig = ''
      # Security headers
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;

      # Rate limiting
      limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
      limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;

      # Hide nginx version
      server_tokens off;
    '';
  };

  # System hardening
  boot.kernel.sysctl = {
    # Network security
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
  };

  # Automatic security updates
  system.autoUpgrade = {
    enable = lib.mkDefault false; # Controlled by auto-update module
    allowReboot = false;
  };

  # Persistent logs for audit trail
  environment.persistence."/nix/persist" = {
    directories = [
      "/var/log"
      "/var/lib/fail2ban"
    ];
  };
}
