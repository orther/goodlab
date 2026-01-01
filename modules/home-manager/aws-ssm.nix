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
      aws-sso-util # AWS SSO utility for profile management
    ];

    # Configure CareCar helper functions
    programs.zsh = {
      initExtra = lib.optionalString cfg.enableCareCar ''

        # CareCar AWS SSM Database Tunnel Helper Functions
        # These functions establish port forwarding tunnels to RDS databases via SSM

        carecar-acceptance-db() {
            echo "🔐 Using carecar-hq-staging AWS profile..."
            export AWS_PROFILE=carecar-hq-staging.AWSAdministratorAccess
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
            echo "🔐 Using carecar-hq-prod AWS profile..."
            export AWS_PROFILE=carecar-hq-prod.AWSAdministratorAccess
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
                echo "🔐 Using carecar-hq-prod AWS profile..."
                export AWS_PROFILE=carecar-hq-prod.AWSAdministratorAccess
            else
                echo "🔐 Using carecar-hq-staging AWS profile..."
                export AWS_PROFILE=carecar-hq-staging.AWSAdministratorAccess
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
        # Quick aliases for setting AWS profile
        "aws-carecar-staging" = "export AWS_PROFILE=carecar-hq-staging.AWSAdministratorAccess";
        "aws-carecar-prod" = "export AWS_PROFILE=carecar-hq-prod.AWSAdministratorAccess";
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
