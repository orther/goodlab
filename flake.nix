{
  description = "doomlab-private: Private homelab configuration with FlakeHub integration";

  inputs = {
    # Core NixOS packages via FlakeHub with semantic versioning
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2405.*";
    impermanence.url = "https://flakehub.com/f/nix-community/impermanence/*";

    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.2405.*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "https://flakehub.com/f/LnL7/nix-darwin/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "https://flakehub.com/f/Mic92/sops-nix/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Keep specialized inputs as GitHub for now (may not be on FlakeHub yet)
    nixarr = {
      url = "github:rasmus-kirk/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nix-darwin,
    ...
  } @ inputs: let
    inherit (self) outputs;

    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    # Enables `nix fmt` at root of repo to format all nix files
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    darwinConfigurations = {
      mair = nix-darwin.lib.darwinSystem {
        system = "x86_64-darwin"; # Specify system for mair
        specialArgs = {inherit inputs outputs;};
        modules = [./machines/mair/configuration.nix];
      };
      stud = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin"; # Specify system for stud
        specialArgs = {inherit inputs outputs;};
        modules = [./machines/stud/configuration.nix];
      };
    };

    nixosConfigurations = {
      iso1chng = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
          ./machines/iso1chng/configuration.nix
        ];
      };

      iso-aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [
          (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
          ./machines/iso1chng/configuration.nix
          {
            # Override hostname for ARM64 variant
            networking.hostName = nixpkgs.lib.mkForce "iso-aarch64";
          }
        ];
      };

      noir = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [./machines/noir/configuration.nix];
      };

      vm = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [./machines/vm/configuration.nix];
      };

      zinc = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs outputs;};
        modules = [./machines/zinc/configuration.nix];
      };
    };
  };
}
