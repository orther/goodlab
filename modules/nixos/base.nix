{
  inputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops

    ./_packages.nix
  ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    efi.canTouchEfiVariables = true;
    timeout = 10;
  };

  nixpkgs.config.allowUnfree = true;
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  sops = {
    defaultSopsFile = ./../../secrets/secrets.yaml;
    age.sshKeyPaths = ["/nix/secret/initrd/ssh_host_ed25519_key"];
    secrets."user-password".neededForUsers = true;
    secrets."user-password" = {};
    # inspo: https://github.com/Mic92/sops-nix/issues/427
    gnupg.sshKeyPaths = [];
  };

  users.mutableUsers = false;
  users.users.orther = {
    isNormalUser = true;
    description = "orther";
    extraGroups = ["networkmanager" "wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDvJx1pyQwQVPPdXlqhJEtUlKyVr4HbZvgbjZ96t75Re"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = config.sops.secrets."user-password".path;
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      openFirewall = true;
    };
    fstrim.enable = true;
  };

  networking = {
    firewall.enable = true;
    networkmanager.enable = true;
  };

  ##systemd.services.NetworkManager-wait-online.enabled = false;
  ##systemd.services.systemd-networkd-wait-online.enable = false;
  # inspo: https://github.com/NixOS/nixpkgs/issues/180175#issuecomment-1658731959
  #systemd.services.NetworkManager-wait-online = {
  #  #enable = false;
  #  serviceConfig = {
  #    ExecStart = ["" "${pkgs.networkmanager}/bin/nm-online -q"];
  #  };
  #};

  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = false;
  time.timeZone = "America/Los_Angeles";
  zramSwap.enable = true;

  environment.persistence."/nix/persist" = {
    # Hide these mounts from the sidebar of file managers
    hideMounts = true;

    directories = [
      "/var/log"
      # inspo: https://github.com/nix-community/impermanence/issues/178
      "/var/lib/nixos"
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
    ];

    users."orther" = {
      directories = [
        "git"

        ".cache"
        ".config"
        ".local"
        {
          directory = ".gnupg";
          mode = "0700";
        }
        {
          directory = ".ssh";
          mode = "0700";
        }
      ];
      files = [
        ".zsh_history"
        #".zshrc"
      ];
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
