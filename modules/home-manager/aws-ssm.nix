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

    region = lib.mkOption {
      type = lib.types.str;
      default = "us-west-2";
      description = "AWS region for SSM and EC2 operations";
    };

    bastionTag = lib.mkOption {
      type = lib.types.str;
      default = "bastion";
      description = "EC2 tag:Name value for bastion instances";
    };

    databases = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          host = lib.mkOption {
            type = lib.types.str;
            description = "Database hostname or endpoint";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 5432;
            description = "Database port";
          };
          localPort = lib.mkOption {
            type = lib.types.port;
            description = "Local port for tunnel";
          };
        };
      });
      default = {};
      description = "Database endpoints for SSM port forwarding tunnels";
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

        # CareCar AWS SSM Helper Functions
        # These functions establish connections to AWS infrastructure via SSM

        # Helper function to find the latest running bastion instance
        _carecar_get_bastion_instance() {
            local instance_id=$(aws ec2 describe-instances \
                --region ${cfg.region} \
                --filters "Name=tag:Name,Values=${cfg.bastionTag}" \
                          "Name=instance-state-name,Values=running" \
                --query "max_by(Reservations[].Instances[], &LaunchTime).InstanceId" \
                --output text 2>&1)

            if [[ -z "$instance_id" || "$instance_id" == "None" || "$instance_id" =~ "error" ]]; then
                echo "❌ Error: No running bastion instance found" >&2
                echo "   Make sure you're authenticated: aws sso login --sso-session carecar" >&2
                return 1
            fi

            echo "$instance_id"
        }
${lib.optionalString (cfg.databases ? acceptance) ''
        # Connect to acceptance database via SSM port forwarding
        carecar-acceptance-db() {
            echo "🔐 Using carecar-hq-staging AWS profile..."
            export AWS_PROFILE=carecar-hq-staging.AWSAdministratorAccess

            echo "🔍 Finding bastion instance..."
            local instance_id=$(_carecar_get_bastion_instance) || return 1

            echo "🚀 Connecting to acceptance database (localhost:${toString cfg.databases.acceptance.localPort})..."
            echo "   Bastion: $instance_id"
            echo "   Database: ${cfg.databases.acceptance.host}:${toString cfg.databases.acceptance.port}"
            echo "   Use Ctrl+C to disconnect"

            aws ssm start-session \
                --region ${cfg.region} \
                --target "$instance_id" \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="${cfg.databases.acceptance.host}",portNumber="${toString cfg.databases.acceptance.port}",localPortNumber="${toString cfg.databases.acceptance.localPort}"
        }
''}${lib.optionalString (cfg.databases ? production) ''
        # Connect to production database via SSM port forwarding
        carecar-prod-db() {
            echo "🔐 Using carecar-hq-prod AWS profile..."
            export AWS_PROFILE=carecar-hq-prod.AWSAdministratorAccess
            echo "⚠️  PRODUCTION DATABASE ACCESS ⚠️"

            echo "🔍 Finding bastion instance..."
            local instance_id=$(_carecar_get_bastion_instance) || return 1

            echo "🚀 Connecting to production database (localhost:${toString cfg.databases.production.localPort})..."
            echo "   Bastion: $instance_id"
            echo "   Database: ${cfg.databases.production.host}:${toString cfg.databases.production.port}"
            echo "   Use Ctrl+C to disconnect"

            aws ssm start-session \
                --region ${cfg.region} \
                --target "$instance_id" \
                --document-name AWS-StartPortForwardingSessionToRemoteHost \
                --parameters host="${cfg.databases.production.host}",portNumber="${toString cfg.databases.production.port}",localPortNumber="${toString cfg.databases.production.localPort}"
        }
''}
        # Interactive SSM session to bastion host
        carecar-ssm-bastion() {
            local env="''${1:-staging}"
            if [[ "$env" == "prod" ]]; then
                echo "🔐 Using carecar-hq-prod AWS profile..."
                export AWS_PROFILE=carecar-hq-prod.AWSAdministratorAccess
            else
                echo "🔐 Using carecar-hq-staging AWS profile..."
                export AWS_PROFILE=carecar-hq-staging.AWSAdministratorAccess
            fi

            echo "🔍 Finding bastion instance..."
            local instance_id=$(_carecar_get_bastion_instance) || return 1

            echo "🚀 Starting SSM session to bastion ($instance_id)..."
            aws ssm start-session \
                --region ${cfg.region} \
                --target "$instance_id"
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
        # IMPORTANT: Must be authenticated with AWS SSO first
        "i-* mi-*" = {
          proxyCommand = "sh -c 'aws ssm start-session --region ${cfg.region} --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p'";
          user = "ubuntu";
          extraOptions = {
            # Disable host key checking for SSM connections:
            # - SSM traffic is encrypted and authenticated via AWS IAM
            # - Instance IDs are ephemeral and change during deployments
            # - Traditional SSH host keys don't add security for SSM
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
          };
        };

        # CareCar acceptance environment bastion
        "carecar-acceptance-bastion" = lib.mkIf cfg.enableCareCar {
          proxyCommand = "sh -c 'aws ssm start-session --region ${cfg.region} --target $(aws ec2 describe-instances --region ${cfg.region} --filters \"Name=tag:Name,Values=${cfg.bastionTag}\" \"Name=instance-state-name,Values=running\" --query \"max_by(Reservations[].Instances[], &LaunchTime).InstanceId\" --output text) --document-name AWS-StartSSHSession --parameters portNumber=%p'";
          user = "ubuntu";
          extraOptions = {
            # Disable host key checking for SSM connections:
            # - SSM traffic is encrypted and authenticated via AWS IAM
            # - Instance IDs are ephemeral and change during deployments
            # - Traditional SSH host keys don't add security for SSM
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
          };
        };

        # CareCar production environment bastion
        "carecar-prod-bastion" = lib.mkIf cfg.enableCareCar {
          proxyCommand = "sh -c 'aws ssm start-session --region ${cfg.region} --target $(aws ec2 describe-instances --region ${cfg.region} --filters \"Name=tag:Name,Values=${cfg.bastionTag}\" \"Name=instance-state-name,Values=running\" --query \"max_by(Reservations[].Instances[], &LaunchTime).InstanceId\" --output text) --document-name AWS-StartSSHSession --parameters portNumber=%p'";
          user = "ubuntu";
          extraOptions = {
            # Disable host key checking for SSM connections:
            # - SSM traffic is encrypted and authenticated via AWS IAM
            # - Instance IDs are ephemeral and change during deployments
            # - Traditional SSH host keys don't add security for SSM
            StrictHostKeyChecking = "no";
            UserKnownHostsFile = "/dev/null";
          };
        };
      };
    };
  };
}
