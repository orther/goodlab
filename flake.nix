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

    nixvim = {
      url = "github:nix-community/nixvim";
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

    doom-emacs = {
      url = "github:doomemacs/doomemacs";
      flake = false;
    };

    # NixOS hardware modules for device-specific configuration
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Keep specialized inputs as GitHub for now (may not be on FlakeHub yet)
    nixarr = {
      url = "github:rasmus-kirk/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative media server configuration (Jellyfin, *arr services)
    nixflix = {
      url = "github:kiriwalawren/nixflix";
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

    devshell = {
      url = "github:numtide/devshell";
    };

    # Claude Code via sadjow/claude-code-nix (hourly upstream checks)
    # Provides faster updates than nixpkgs and Node.js 22 LTS runtime
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Local developer services orchestration
    process-compose-flake = {
      url = "github:platonic-systems/process-compose-flake";
    };
    services-flake = {
      url = "github:juspay/services-flake";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nix-darwin,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      # Bring in treefmt, devshell, and process-compose modules
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.devshell.flakeModule
        inputs.process-compose-flake.flakeModule
      ];

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        # Research Relay OCI images for GHCR
        # NOTE: Odoo image commented out - use official Docker Hub image instead
        # PDF-intake can be built if needed
        packages = {
          # # Odoo Docker image - NOT AVAILABLE IN NIXPKGS
          # # Use official image: docker pull odoo:17.0
          # odooImage = pkgs.dockerTools.buildImage {
          #   name = "ghcr.io/scientific-oops/research-relay-odoo";
          #   tag = "latest";
          #   created = "now";
          # };

          # PDF-intake service image
          pdfIntakeImage = let
            pythonEnv = pkgs.python311.withPackages (ps:
              with ps; [
                fastapi
                uvicorn
                celery
                redis
                # pypdf2  # May not be in nixpkgs - install via pip if needed
                pandas
                requests
                pydantic
              ]);
          in
            pkgs.dockerTools.buildImage {
              name = "ghcr.io/scientific-oops/research-relay-pdf-intake";
              tag = "latest";
              created = "now";
              config = {
                Cmd = ["${pythonEnv}/bin/uvicorn" "app.main:app" "--host" "0.0.0.0" "--port" "8070"];
                ExposedPorts = {"8070/tcp" = {};};
                WorkingDir = "/app";
              };
              copyToRoot = pkgs.buildEnv {
                name = "pdf-intake-root";
                paths = [pythonEnv pkgs.coreutils pkgs.bash];
                pathsToLink = ["/bin" "/lib"];
              };
            };
        };

        # treefmt configuration (nix fmt)
        treefmt = {
          projectRootFile = "flake.nix";
          programs = {
            alejandra.enable = true;
            shfmt.enable = true;
            prettier.enable = true;
          };
        };

        # Enables `nix fmt` at root of repo to format all supported files
        formatter = config.treefmt.build.wrapper;

        # Static analysis checks
        checks = {
          formatting = pkgs.runCommand "treefmt-check" {nativeBuildInputs = [config.treefmt.build.wrapper];} ''
            export HOME=$(mktemp -d)
            tmpdir=$(mktemp -d)
            cp -R ${./.} "$tmpdir/src"
            chmod -R u+w "$tmpdir/src"
            cd "$tmpdir/src"
            treefmt --fail-on-change
            mkdir -p "$out"
            touch "$out"/success
          '';

          statix = pkgs.runCommand "statix-check" {nativeBuildInputs = [pkgs.statix];} ''
            export HOME=$(mktemp -d)
            cd ${./.}
            statix check . --ignore W20 || true
            mkdir -p "$out"
            touch "$out"/success
          '';

          deadnix = pkgs.runCommand "deadnix-check" {nativeBuildInputs = [pkgs.deadnix];} ''
            export HOME=$(mktemp -d)
            cd ${./.}
            deadnix --fail
            mkdir -p "$out"
            touch "$out"/success
          '';

          # Lightweight NixOS eval smoke test (no build), to catch regressions early
          nixosEval-noir = let
            sys = inputs.nixpkgs.lib.nixosSystem {
              # Evaluate as Linux regardless of host platform
              system = "x86_64-linux";
              specialArgs = {
                inherit inputs;
                inherit (self) outputs;
              };
              modules = [./machines/noir/configuration.nix];
            };
            summary = builtins.toJSON {
              platform = sys.pkgs.stdenv.hostPlatform.system;
              stateVersion = sys.config.system.stateVersion or null;
            };
          in
            pkgs.writeText "nixos-eval-noir.json" summary;

          nixosEval-zinc = let
            sys = inputs.nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = {
                inherit inputs;
                inherit (self) outputs;
              };
              modules = [./machines/zinc/configuration.nix];
            };
            summary = builtins.toJSON {
              platform = sys.pkgs.stdenv.hostPlatform.system;
              stateVersion = sys.config.system.stateVersion or null;
            };
          in
            pkgs.writeText "nixos-eval-zinc.json" summary;

          nixosEval-pie = let
            sys = inputs.nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = {
                inherit inputs;
                inherit (self) outputs;
              };
              modules = [./machines/pie/configuration.nix];
            };
            summary = builtins.toJSON {
              platform = sys.pkgs.stdenv.hostPlatform.system;
              stateVersion = sys.config.system.stateVersion or null;
            };
          in
            pkgs.writeText "nixos-eval-pie.json" summary;
        };

        # Expose a convenient app alias for process-compose devservices
        apps.devservices = {
          type = "app";
          program = "${config.process-compose.devservices.package}/bin/process-compose";
        };

        # Developer services bundle via services-flake + process-compose
        # Usage:
        #   nix run .#devservices         (start)
        #   nix run .#devservices -- stop (stop)
        process-compose."devservices" = {
          imports = [inputs.services-flake.processComposeModules.default];
          services = {
            # Postgres on localhost:5432 (services-flake default settings)
            postgres.pg.enable = true;
            # Redis on localhost:6379
            redis.r1.enable = true;
          };
        };

        devshells = {
          default = {
            packages = with pkgs; [
              git
              just
              sops
              alejandra
              shfmt
              nodejs
              statix
              deadnix
              nil
            ];
            commands = [
              {
                name = "fmt";
                command = "nix fmt";
                category = "dev";
                help = "Format repository";
              }
              {
                name = "check";
                command = "nix flake check";
                category = "dev";
                help = "Run repo checks";
              }
            ];
          };

          ops = {
            packages = with pkgs; [
              nixos-rebuild
              cachix
            ];
          };
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
            server-base = import ./modules/home-manager/server-base.nix;
            fonts = import ./modules/home-manager/fonts.nix;
            alacritty = import ./modules/home-manager/alacritty.nix;
            doom = import ./modules/home-manager/doom.nix;
            "1password" = import ./modules/home-manager/1password.nix;
            desktop = import ./modules/home-manager/desktop.nix;
            aws-ssm = import ./modules/home-manager/aws-ssm.nix;
            claude-code = import ./modules/home-manager/claude-code.nix;
          };
        };

        darwinConfigurations = {
          mair = nix-darwin.lib.darwinSystem {
            system = "x86_64-darwin"; # Specify system for mair
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
            };
            modules = [
              ./machines/mair/configuration.nix
              {
                nixpkgs.config.allowUnfree = true;
                nixpkgs.overlays = [
                  (import ./overlays/claude-code-nix.nix inputs)
                ];
              }
            ];
          };
          stud = nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin"; # Specify system for stud
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
            };
            modules = [
              ./machines/stud/configuration.nix
              {
                nixpkgs.config.allowUnfree = true;
                nixpkgs.overlays = [
                  (import ./overlays/claude-code-nix.nix inputs)
                ];
              }
            ];
          };
          nblap = nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin"; # Apple Silicon MacBook (work)
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
            };
            modules = [
              ./machines/nblap/configuration.nix
              {
                nixpkgs.config.allowUnfree = true;
                nixpkgs.overlays = [
                  # Fix sops-nix Go builds in corporate proxy environments
                  (import ./overlays/sops-nix-goproxy.nix)
                  # Add claude-code-nix (filtered out by corporateNetwork check)
                  (import ./overlays/claude-code-nix.nix inputs)
                ];
              }
            ];
          };
        };

        nixosConfigurations = {
          iso1chng = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
            };
            modules = [
              (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
              ./machines/iso1chng/configuration.nix
            ];
          };

          iso-aarch64 = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
            };
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
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
            };
            modules = [./machines/noir/configuration.nix];
          };

          vm = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
            };
            modules = [./machines/vm/configuration.nix];
          };

          zinc = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
            };
            modules = [./machines/zinc/configuration.nix];
          };

          pie = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
            };
            modules = [./machines/pie/configuration.nix];
          };
        };
      };
    };
}
