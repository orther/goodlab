{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.aws-ssm;
in {
  options.programs.aws-ssm = {
    enable = lib.mkEnableOption "AWS Systems Manager (SSM) configuration";

    enableSshProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SSH ProxyCommand for SSM access";
    };

    enableCareCar = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable CareCar-specific database tunnel helper functions";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install required packages
    home.packages = with pkgs; [
      awscli2 # AWS CLI v2
      ssm-session-manager-plugin # AWS Session Manager plugin
      awsume # AWS credential management tool
    ];

    # Configure awsume shell integration and CareCar helpers
    programs.zsh = {
      initExtra = ''
        # awsume alias and autocomplete configuration
        alias awsume="source \$(${pkgs.awsume}/bin/awsume)"

        # awsume autocompletion
        if command -v awsume >/dev/null 2>&1; then
          fpath=(${pkgs.awsume}/share/zsh/site-functions $fpath)
        fi
      '' + lib.optionalString cfg.enableCareCar ''

        # CareCar AWS SSM Database Tunnel Helper Functions
        # These functions establish port forwarding tunnels to RDS databases via SSM

        carecar-acceptance-db() {
            echo "🔐 Assuming carecar-hq-staging AWS role..."
            awsume carecar-hq-staging.AWSAdministratorAccess --region us-west-2
            echo "🚀 Connecting to acceptance database (localhost:5434)..."
            echo "   Database: acceptance-db.cbpfxk1gzmnb.us-west-2.rds.amazonaws.com"
            echo "   Use Ctrl+C to disconnect"
            aws ssm start-session \
                --target $(aws ec2 describe-instances \
                    --filters "Name=tag:Name,Values=bastion" \
                              "Name=instance-state-name,Values=running" \
                    --query "max_by(Reservations[].Instances[], &LaunchTime).InstanceId" \
                    --output text) \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="acceptance-db.cbpfxk1gzmnb.us-west-2.rds.amazonaws.com",portNumber="5432",localPortNumber="5434"
        }

        carecar-prod-db() {
            echo "🔐 Assuming carecar-hq-prod AWS role..."
            awsume carecar-hq-prod.AWSAdministratorAccess --region us-west-2
            echo "⚠️  PRODUCTION DATABASE ACCESS ⚠️"
            echo "🚀 Connecting to production database (localhost:5433)..."
            echo "   Database: prod-db.c53hlgaegw8h.us-west-2.rds.amazonaws.com"
            echo "   Use Ctrl+C to disconnect"
            aws ssm start-session \
                --target $(aws ec2 describe-instances \
                    --filters "Name=tag:Name,Values=bastion" \
                              "Name=instance-state-name,Values=running" \
                    --query "max_by(Reservations[].Instances[], &LaunchTime).InstanceId" \
                    --output text) \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="prod-db.c53hlgaegw8h.us-west-2.rds.amazonaws.com",portNumber="5432",localPortNumber="5433"
        }

        # Generic SSM session helper
        carecar-ssm-bastion() {
            local env="''${1:-staging}"
            if [[ "$env" == "prod" ]]; then
                echo "🔐 Assuming carecar-hq-prod AWS role..."
                awsume carecar-hq-prod.AWSAdministratorAccess --region us-west-2
            else
                echo "🔐 Assuming carecar-hq-staging AWS role..."
                awsume carecar-hq-staging.AWSAdministratorAccess --region us-west-2
            fi
            echo "🚀 Starting SSM session to bastion..."
            aws ssm start-session \
                --target $(aws ec2 describe-instances \
                    --filters "Name=tag:Name,Values=bastion" \
                              "Name=instance-state-name,Values=running" \
                    --query "max_by(Reservations[].Instances[], &LaunchTime).InstanceId" \
                    --output text)
        }
      '';

      shellAliases = lib.mkIf cfg.enableCareCar {
        # Quick aliases for assuming roles
        "awsume-carecar-staging" = "awsume carecar-hq-staging.AWSAdministratorAccess --region us-west-2";
        "awsume-carecar-prod" = "awsume carecar-hq-prod.AWSAdministratorAccess --region us-west-2";
      };
    };

    # Configure SSH to use SSM as a transparent proxy
    programs.ssh = lib.mkIf cfg.enableSshProxy {
      enable = true;
      matchBlocks = {
        # Generic SSM proxy for any EC2 instance ID
        # Usage: ssh i-<instance-id> or ssh mi-<instance-id>
        # IMPORTANT: Must authenticate with awsume first
        "i-* mi-*" = {
          proxyCommand = "sh -c 'aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p'";
          user = "ubuntu";
          extraOptions = {
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
          };
        };

        # CareCar acceptance environment bastion
        "carecar-acceptance-bastion" = lib.mkIf cfg.enableCareCar {
          proxyCommand = "sh -c 'aws ssm start-session --target $(aws ec2 describe-instances --filters \"Name=tag:Name,Values=bastion\" \"Name=instance-state-name,Values=running\" --query \"Reservations[0].Instances[0].InstanceId\" --output text --region us-west-2) --document-name AWS-StartSSHSession --parameters portNumber=%p --region us-west-2'";
          user = "ubuntu";
          extraOptions = {
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
          };
        };

        # CareCar production environment bastion
        "carecar-prod-bastion" = lib.mkIf cfg.enableCareCar {
          proxyCommand = "sh -c 'aws ssm start-session --target $(aws ec2 describe-instances --filters \"Name=tag:Name,Values=bastion\" \"Name=instance-state-name,Values=running\" --query \"Reservations[0].Instances[0].InstanceId\" --output text --region us-west-2) --document-name AWS-StartSSHSession --parameters portNumber=%p --region us-west-2'";
          user = "ubuntu";
          extraOptions = {
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
          };
        };
      };
    };
  };
}
