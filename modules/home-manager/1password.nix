{
  lib,
  pkgs,
  ...
}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # Define a default match block and set IdentityAgent there,
    # avoiding raw extraConfig so HM's assertion is satisfied.
    matchBlocks = {
      # Repository-specific SSH identity for pep-store
      "github-pep-store" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/lab_project_20250702";
        identitiesOnly = true;
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };

      # Corporate GitHub and internal hosts
      "github.com 10.4.0.29 10.4.0.198" = {
        identitiesOnly = true;
        identityFile = "/Users/orther/.ssh/id_rsa-arson";
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };

      # Corporate bastion host
      "bastion.hq-staging.aws.carecar.co" = {
        identitiesOnly = true;
        identityFile = "/Users/orther/.ssh/id_rsa-arson";
        user = "borther";
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };

      # Research Relay server
      "104.194.132.119" = {
        user = "root";
        identityFile = "~/.ssh/lab_project_20250702";
        identitiesOnly = true;
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };

      # Research Relay shorthand
      "rr" = {
        hostname = "104.194.132.119";
        user = "root";
        identityFile = "~/.ssh/lab_project_20250702";
        identitiesOnly = true;
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };

      # Research Relay Deploy shorthand
      "drr" = {
        hostname = "104.194.132.119";
        user = "deploy";
        identityFile = "~/.ssh/lab_project_20250702";
        identitiesOnly = true;
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };

      # Default 1Password agent for all other hosts
      "*" = {
        extraOptions = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.isLinux {IdentityAgent = "~/.1password/agent.sock";})
          (lib.mkIf pkgs.stdenv.isDarwin {IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";})
        ];
      };
    };
  };

  programs.git = {
    userName = "Brandon Orther";
    userEmail = "brandon@orther.dev";
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDvJx1pyQwQVPPdXlqhJEtUlKyVr4HbZvgbjZ96t75Re";
      signByDefault = true;
    };
    extraConfig = {
      push = {autoSetupRemote = true;};
      gpg = {format = "ssh";};
      gpg."ssh".program = lib.mkMerge [
        (lib.mkIf pkgs.stdenv.isLinux "${pkgs._1password-gui}/bin/op-ssh-sign")
        (lib.mkIf pkgs.stdenv.isDarwin "/Applications/1Password.app/Contents/MacOS/op-ssh-sign")
      ];
    };
  };
}
