{
  description = "goodlab: Public homelab configuration with FlakeHub integration";

  inputs = {
    # Bootstrap with GitHub URLs first, will migrate to FlakeHub after CI is working
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    impermanence.url = "github:nix-community/impermanence";

    # Modern flake orchestration
    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-doom-emacs = {
      url = "github:nix-community/nix-doom-emacs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    doom-emacs = {
      url = "github:doomemacs/doomemacs";
      flake = false;
    };

    # Keep specialized inputs as GitHub for now (may not be on FlakeHub yet)
    nixarr = {
      url = "github:rasmus-kirk/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
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

    # Formatting orchestrator (Stage 3)
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nix-darwin,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      # Bring in treefmt-nix flake module
      imports = [ inputs.treefmt-nix.flakeModule ];

      perSystem = { config, pkgs, system, lib, ... }: {
        # treefmt configuration (nix fmt)
        treefmt = {
          projectRootFile = "flake.nix";
          programs.alejandra.enable = true;
          programs.shfmt.enable = true;
          programs.prettier.enable = true;
        };

        # Enables `nix fmt` at root of repo to format all supported files
        formatter = config.treefmt.build.wrapper;

        # Static analysis checks
        checks = {
          # Use the treefmt wrapper directly to perform a failing check on unformatted files
          formatting = pkgs.runCommand "treefmt-check" { nativeBuildInputs = [ config.treefmt.build.wrapper ]; } ''
            export HOME=$(mktemp -d)
            cd ${./.}
            treefmt --fail-on-change
            mkdir -p "$out"
            touch "$out"/success
          '';

          statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
            export HOME=$(mktemp -d)
            cd ${./.}
            statix check .
            mkdir -p "$out"
            touch "$out"/success
          '';

          deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            export HOME=$(mktemp -d)
            cd ${./.}
            deadnix --fail
            mkdir -p "$out"
            touch "$out"/success
          '';
        };
      };

      flake = {
        # Export reusable module sets for downstream reuse and internal imports
        darwinModules = {
          base = import ./modules/macos/base.nix;
          work = import ./modules/macos/work.nix;
          zscaler = import ./modules/macos/zscaler.nix;
        };

        nixosModules = {
          base = import ./modules/nixos/base.nix;
          desktop = import ./modules/nixos/desktop.nix;
          iso = import ./modules/nixos/iso.nix;
          "remote-unlock" = import ./modules/nixos/remote-unlock.nix;
          amdgpu = import ./modules/nixos/amdgpu.nix;
          "auto-update" = import ./modules/nixos/auto-update.nix;
        };

        # Home Manager module exports (nest under lib to avoid unknown output warnings)
        lib = {
          hmModules = {
            base = import ./modules/home-manager/base.nix;
            fonts = import ./modules/home-manager/fonts.nix;
            alacritty = import ./modules/home-manager/alacritty.nix;
            doom = import ./modules/home-manager/doom.nix;
            "1password" = import ./modules/home-manager/1password.nix;
            desktop = import ./modules/home-manager/desktop.nix;
          };
        };

        darwinConfigurations = {
          mair = nix-darwin.lib.darwinSystem {
            system = "x86_64-darwin"; # Specify system for mair
            specialArgs = { inherit inputs; inherit (self) outputs; };
            modules = [
              ./machines/mair/configuration.nix
              {
                nixpkgs.config.allowUnfree = true;
              }
            ];
          };
          stud = nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin"; # Specify system for stud
            specialArgs = { inherit inputs; inherit (self) outputs; };
            modules = [
              ./machines/stud/configuration.nix
              {
                nixpkgs.config.allowUnfree = true;
              }
            ];
          };
          nblap = nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin"; # Apple Silicon MacBook (work)
            specialArgs = { inherit inputs; inherit (self) outputs; };
            modules = [
              ./machines/nblap/configuration.nix
              {
                nixpkgs.config.allowUnfree = true;
              }
            ];
          };
        };

        nixosConfigurations = {
          iso1chng = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; inherit (self) outputs; };
            modules = [
              (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
              ./machines/iso1chng/configuration.nix
            ];
          };

          iso-aarch64 = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            specialArgs = { inherit inputs; inherit (self) outputs; };
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
            specialArgs = { inherit inputs; inherit (self) outputs; };
            modules = [./machines/noir/configuration.nix];
          };

          vm = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            specialArgs = { inherit inputs; inherit (self) outputs; };
            modules = [./machines/vm/configuration.nix];
          };

          zinc = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; inherit (self) outputs; };
            modules = [./machines/zinc/configuration.nix];
          };
        };
      };
    };
}
