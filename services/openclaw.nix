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
  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/openclaw";
        user = "openclaw";
        group = "openclaw";
        mode = "0750";
      }
    ];
  };
}
