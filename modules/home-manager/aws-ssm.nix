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

    enableHeartbeat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable heartbeat mechanism to keep SSM sessions alive during long operations";
    };

    heartbeatInterval = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Seconds between heartbeat checks (default: 5)";
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

    stagingProfile = lib.mkOption {
      type = lib.types.str;
      default = "carecar-hq-staging.AWSAdministratorAccess";
      description = "AWS profile name for staging environment";
    };

    productionProfile = lib.mkOption {
      type = lib.types.str;
      default = "carecar-hq-prod.AWSAdministratorAccess";
      description = "AWS profile name for production environment";
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

                # Helper function to check AWS authentication status
                _carecar_check_auth() {
                    local check_output=$(aws sts get-caller-identity 2>&1)
                    local exit_code=$?

                    # Check both exit code and output content for errors
                    if [[ $exit_code -ne 0 ]] || [[ "$check_output" =~ "Error" ]] || [[ "$check_output" =~ "expired" ]] || [[ "$check_output" =~ "Unable to locate credentials" ]]; then
                        echo "" >&2
                        echo "❌ AWS authentication failed" >&2
                        if [[ "$check_output" =~ "Token has expired" ]] || [[ "$check_output" =~ "expired" ]]; then
                            echo "   Your SSO session has expired" >&2
                        elif [[ "$check_output" =~ "No AWS credentials" ]] || [[ "$check_output" =~ "Unable to locate credentials" ]]; then
                            echo "   No AWS credentials found" >&2
                        else
                            echo "   $check_output" >&2
                        fi
                        echo "" >&2
                        echo "🔑 Would you like to run: aws sso login --sso-session carecar" >&2
                        echo -n "   (y/n)? " >&2
                        read -r response

                        if [[ "$response" =~ ^[Yy]$ ]]; then
                            echo "" >&2
                            echo "🔐 Running: aws sso login --sso-session carecar" >&2
                            aws sso login --sso-session carecar
                            local login_result=$?

                            if [[ $login_result -eq 0 ]]; then
                                echo "" >&2
                                echo "✅ Successfully authenticated. Continuing..." >&2
                                echo "" >&2
                                return 0
                            else
                                echo "" >&2
                                echo "❌ Login failed" >&2
                                echo "" >&2
                                return 1
                            fi
                        else
                            echo "" >&2
                            echo "ℹ️  Skipping login. You can authenticate later with:" >&2
                            echo "   aws sso login --sso-session carecar" >&2
                            echo "" >&2
                            return 1
                        fi
                    fi
                    return 0
                }

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
                        echo "   Verify you're authenticated and have access to the bastion" >&2
                        return 1
                    fi

                    echo "$instance_id"
                }

                # Helper function to run heartbeat for SSM sessions
                _carecar_start_heartbeat() {
                    local session_pid=$1
                    local local_port=$2

                    if ! command -v nc >/dev/null 2>&1; then
                        echo "⚠️  'nc' (netcat) not found — heartbeat disabled" >&2
                        return 0
                    fi

                    echo "💓 Starting heartbeat to keep SSM session alive..." >&2

                    (
                        # Visual indicator: set terminal background to green
                        printf '\033]11;#007700\007'

                        SPINNER=('/' '|' '\' '-')
                        i=0
                        while ps -p $session_pid >/dev/null 2>&1; do
                            # Check if port is still open (this keeps the connection alive)
                            nc -z localhost "$local_port" >/dev/null 2>&1
                            printf "\r💓 Keeping session alive %s" "''${SPINNER[$((i % 4))]}" >&2
                            i=$(( (i + 1) % 4 ))
                            sleep ${toString cfg.heartbeatInterval}
                        done

                        # Reset terminal background to default
                        printf '\033]111\007'
                        echo -e "\r✅ Session ended.                             " >&2
                    ) &

                    echo $!
                }
        ${lib.optionalString (cfg.databases ? acceptance) ''
          # Connect to acceptance database via SSM port forwarding
          carecar-acceptance-db() {
              echo "🔐 Using staging AWS profile..."
              export AWS_PROFILE=${cfg.stagingProfile}

              _carecar_check_auth || return 1

              echo "🔍 Finding bastion instance..."
              local instance_id=$(_carecar_get_bastion_instance) || return 1

              # Read database host from file if it starts with /, otherwise use as-is
              local db_host="${cfg.databases.acceptance.host}"
              if [[ "$db_host" == /* ]]; then
                  db_host=$(cat "$db_host")
              fi

              echo "🚀 Connecting to acceptance database (localhost:${toString cfg.databases.acceptance.localPort})..."
              echo "   Bastion: $instance_id"
              echo "   Database: $db_host:${toString cfg.databases.acceptance.port}"
              echo "   Use Ctrl+C to disconnect"
              echo ""

              ${
            if cfg.enableHeartbeat
            then ''
              # Start SSM session in background
              aws ssm start-session \
                  --region ${cfg.region} \
                  --target "$instance_id" \
                  --document-name AWS-StartPortForwardingSessionToRemoteHost \
                  --parameters host="$db_host",portNumber="${toString cfg.databases.acceptance.port}",localPortNumber="${toString cfg.databases.acceptance.localPort}" &

              local session_pid=$!

              # Start heartbeat to keep connection alive
              local heartbeat_pid=$(_carecar_start_heartbeat "$session_pid" "${toString cfg.databases.acceptance.localPort}")

              # Set up cleanup trap
              trap "kill $heartbeat_pid 2>/dev/null; wait $heartbeat_pid 2>/dev/null" EXIT INT TERM

              # Wait for SSM session to end
              wait "$session_pid"

              # Clean up heartbeat
              echo "" >&2
              echo "🧹 Cleaning up heartbeat..." >&2
              kill "$heartbeat_pid" 2>/dev/null
              wait "$heartbeat_pid" 2>/dev/null
            ''
            else ''
              # Run SSM session without heartbeat
              aws ssm start-session \
                  --region ${cfg.region} \
                  --target "$instance_id" \
                  --document-name AWS-StartPortForwardingSessionToRemoteHost \
                  --parameters host="$db_host",portNumber="${toString cfg.databases.acceptance.port}",localPortNumber="${toString cfg.databases.acceptance.localPort}"
            ''
          }
          }
        ''}${lib.optionalString (cfg.databases ? production) ''
          # Connect to production database via SSM port forwarding
          carecar-prod-db() {
              echo "🔐 Using production AWS profile..."
              export AWS_PROFILE=${cfg.productionProfile}
              echo "⚠️  PRODUCTION DATABASE ACCESS ⚠️"

              _carecar_check_auth || return 1

              echo "🔍 Finding bastion instance..."
              local instance_id=$(_carecar_get_bastion_instance) || return 1

              # Read database host from file if it starts with /, otherwise use as-is
              local db_host="${cfg.databases.production.host}"
              if [[ "$db_host" == /* ]]; then
                  db_host=$(cat "$db_host")
              fi

              echo "🚀 Connecting to production database (localhost:${toString cfg.databases.production.localPort})..."
              echo "   Bastion: $instance_id"
              echo "   Database: $db_host:${toString cfg.databases.production.port}"
              echo "   Use Ctrl+C to disconnect"
              echo ""

              ${
            if cfg.enableHeartbeat
            then ''
              # Start SSM session in background
              aws ssm start-session \
                  --region ${cfg.region} \
                  --target "$instance_id" \
                  --document-name AWS-StartPortForwardingSessionToRemoteHost \
                  --parameters host="$db_host",portNumber="${toString cfg.databases.production.port}",localPortNumber="${toString cfg.databases.production.localPort}" &

              local session_pid=$!

              # Start heartbeat to keep connection alive
              local heartbeat_pid=$(_carecar_start_heartbeat "$session_pid" "${toString cfg.databases.production.localPort}")

              # Set up cleanup trap
              trap "kill $heartbeat_pid 2>/dev/null; wait $heartbeat_pid 2>/dev/null" EXIT INT TERM

              # Wait for SSM session to end
              wait "$session_pid"

              # Clean up heartbeat
              echo "" >&2
              echo "🧹 Cleaning up heartbeat..." >&2
              kill "$heartbeat_pid" 2>/dev/null
              wait "$heartbeat_pid" 2>/dev/null
            ''
            else ''
              # Run SSM session without heartbeat
              aws ssm start-session \
                  --region ${cfg.region} \
                  --target "$instance_id" \
                  --document-name AWS-StartPortForwardingSessionToRemoteHost \
                  --parameters host="$db_host",portNumber="${toString cfg.databases.production.port}",localPortNumber="${toString cfg.databases.production.localPort}"
            ''
          }
          }
        ''}
                # Interactive SSM session to bastion host
                carecar-ssm-bastion() {
                    local env="''${1:-staging}"
                    if [[ "$env" == "prod" ]]; then
                        echo "🔐 Using production AWS profile..."
                        export AWS_PROFILE=${cfg.productionProfile}
                    else
                        echo "🔐 Using staging AWS profile..."
                        export AWS_PROFILE=${cfg.stagingProfile}
                    fi

                    _carecar_check_auth || return 1

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
        "aws-carecar-staging" = "export AWS_PROFILE=${cfg.stagingProfile}";
        "aws-carecar-prod" = "export AWS_PROFILE=${cfg.productionProfile}";
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
          proxyCommand = "sh -c 'INSTANCE_ID=$(aws ec2 describe-instances --region ${cfg.region} --filters \"Name=tag:Name,Values=${cfg.bastionTag}\" \"Name=instance-state-name,Values=running\" --query \"max_by(Reservations[].Instances[], &LaunchTime).InstanceId\" --output text 2>&1); if [ -z \"$INSTANCE_ID\" ] || [ \"$INSTANCE_ID\" = \"None\" ] || echo \"$INSTANCE_ID\" | grep -q \"error\\|Error\\|expired\"; then echo \"Error: Failed to find bastion instance. Check AWS credentials and permissions.\" >&2; exit 1; fi; aws ssm start-session --region ${cfg.region} --target \"$INSTANCE_ID\" --document-name AWS-StartSSHSession --parameters portNumber=%p'";
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
          proxyCommand = "sh -c 'INSTANCE_ID=$(aws ec2 describe-instances --region ${cfg.region} --filters \"Name=tag:Name,Values=${cfg.bastionTag}\" \"Name=instance-state-name,Values=running\" --query \"max_by(Reservations[].Instances[], &LaunchTime).InstanceId\" --output text 2>&1); if [ -z \"$INSTANCE_ID\" ] || [ \"$INSTANCE_ID\" = \"None\" ] || echo \"$INSTANCE_ID\" | grep -q \"error\\|Error\\|expired\"; then echo \"Error: Failed to find bastion instance. Check AWS credentials and permissions.\" >&2; exit 1; fi; aws ssm start-session --region ${cfg.region} --target \"$INSTANCE_ID\" --document-name AWS-StartSSHSession --parameters portNumber=%p'";
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
