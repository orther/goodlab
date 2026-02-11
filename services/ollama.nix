# Ollama - local LLM inference for OpenClaw heartbeats
# Uses llama3.2:3b (~2GB RAM, no GPU needed)
{...}: {
  services.ollama = {
    enable = true;
    host = "127.0.0.1"; # Bind only to localhost
    port = 11434;
    loadModels = ["llama3.2:3b"];
    # Use static user/group to work with impermanence
    # (avoids DynamicUser conflict with persistent /var/lib/ollama)
    user = "ollama";
    group = "ollama";
  };

  # Create static ollama user/group for impermanence compatibility
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    home = "/var/lib/ollama";
  };
  users.groups.ollama = {};

  # Persist model data across reboots (impermanence)
  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/ollama";
        user = "ollama";
        group = "ollama";
        mode = "0700";
      }
    ];
  };
}
