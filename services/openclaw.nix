# OpenClaw shared infrastructure
# Docker for sandbox and persistent state directory
{...}: {
  # Docker is required for OpenClaw's sandboxed execution
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Persist openclaw state across reboots (impermanence)
  # Note: main branch module uses /var/lib/openclaw-gateway
  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/openclaw-gateway";
        user = "openclaw-gateway";
        group = "openclaw-gateway";
        mode = "0750";
      }
    ];
  };
}
