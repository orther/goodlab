{
  config,
  inputs,
  outputs,
  ...
}: {
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops

    ./hardware-configuration.nix

    inputs.self.darwinModules.base
    inputs.self.darwinModules.wireguard
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      orther = {
        imports = [
          inputs.self.lib.hmModules.base
          inputs.self.lib.hmModules.ghostty
          inputs.self.lib.hmModules.fonts
          inputs.self.lib.hmModules."1password"
          inputs.self.lib.hmModules.doom
          inputs.self.lib.hmModules.claude-code
        ];

        # Bitcoin node tunnel via Research Relay
        # Usage: ssh btc-tunnel
        programs.ssh.matchBlocks."btc-tunnel" = {
          hostname = "btc.research-relay.com";
          user = "root";
          identityFile = "~/.ssh/id_ed25519";
          identitiesOnly = true;
          localForwards = [
            {
              bind.port = 8332;
              host.address = "127.0.0.1";
              host.port = 8332;
            }
          ];
          extraOptions = {
            AddKeysToAgent = "yes";
          };
        };
      };
    };
  };

  sops = {
    defaultSopsFile = ./../../secrets/secrets.yaml;
    age.keyFile = "/Users/${config.system.primaryUser}/.config/sops/age/keys.txt";
  };

  # WireGuard VPN tunnel to shops-btc-01
  local.wireguard.interfaces."shops-btc-01" = {
    address = "10.100.0.2/32";
    privateKeySecret = "wireguard-shops-btc-01-private-key";
    peers = [
      {
        publicKey = "Td09/lwlkLUZgl+RFG5u40BWcGz6/8b2YYerpUkxqAc=";
        endpoint = "204.168.195.168:51820";
        allowedIPs = ["10.100.0.1/32"];
        persistentKeepalive = 25;
      }
    ];
  };

  networking = {
    hostName = "stud";
    computerName = "stud";
    localHostName = "stud";
  };
}
