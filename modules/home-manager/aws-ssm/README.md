# AWS Systems Manager (SSM) Configuration Module

This home-manager module provides secure, audited access to AWS infrastructure via AWS Systems Manager (SSM), eliminating the need to manage SSH keys, open inbound ports, or share credentials.

## Features

### Core Capabilities

- **AWS CLI v2** and **Session Manager Plugin** for SSM connectivity
- **awsume** for seamless AWS credential and role management with MFA support
- **SSH ProxyCommand** integration for transparent SSM access via standard `ssh` and `scp` commands
- **Automatic audit logging** to CloudWatch for all sessions
- **Outbound-only connections** with no open inbound ports required

### CareCar-Specific Features

When `enableCareCar` is enabled, provides:

- **Database tunnel functions** for quick access to RDS databases
- **Environment-specific SSH aliases** for bastion hosts
- **Helper functions** for common CareCar infrastructure operations

## Prerequisites

Before using this module, ensure you have:

1. **AWS account access** to CareCar infrastructure
2. **Okta SSO** configured for AWS access
3. **MFA device** enrolled (required for production access)
4. **Network access** to AWS Systems Manager endpoints

## Configuration

### Basic Setup

Add the module to your home-manager configuration:

```nix
{
  imports = [
    inputs.self.lib.hmModules.aws-ssm
  ];

  programs.aws-ssm = {
    enable = true;
    enableSshProxy = true;      # Enable SSH/SCP via SSM
    enableCareCar = false;       # Enable CareCar-specific helpers
  };
}
```

### CareCar Setup

For CareCar infrastructure access on work machines:

```nix
{
  programs.aws-ssm = {
    enable = true;
    enableSshProxy = true;
    enableCareCar = true;  # Adds database tunnels and environment aliases
  };
}
```

## Initial Setup

After enabling the module and rebuilding your configuration, complete the following one-time setup:

### 1. Configure awsume

Initialize awsume configuration:

```bash
awsume-configure
```

This creates `~/.awsume/config.yaml` with default settings.

### 2. Configure AWS SSO

Set up AWS Single Sign-On:

```bash
aws configure sso
```

Follow the prompts:
- **SSO start URL**: `https://carecar.awsapps.com/start/#` (note the trailing `/#`)
- **SSO region**: `us-east-1`
- **Account**: Select your default account (e.g., `carecar-hq-staging`)
- **Role**: Select your role (e.g., `AWSAdministratorAccess`)
- **CLI profile name**: Use a descriptive name (e.g., `carecar-staging-admin`)

### 3. Populate All Available Profiles

Automatically configure all accessible AWS accounts:

```bash
aws-sso-util configure populate -u https://carecar.awsapps.com/start/#
```

This discovers and configures profiles for all accounts and roles you have access to, including:
- `carecar-hq-staging.AWSAdministratorAccess`
- `carecar-hq-prod.AWSAdministratorAccess`
- And any other accessible accounts

### 4. Verify Configuration

List available profiles:

```bash
aws configure list-profiles
```

Test authentication:

```bash
awsume carecar-hq-staging.AWSAdministratorAccess --region us-west-2
aws sts get-caller-identity
```

## Usage

### Authentication Workflow

**IMPORTANT**: You must authenticate with AWS SSO before using SSH/SCP or database tunnels. SSM relies on AWS credentials from your environment.

```bash
# Login to AWS SSO (opens browser, only needed once per session or when expired)
aws sso login --sso-session carecar

# Then set your AWS profile for the session:
# For staging environment
export AWS_PROFILE=carecar-hq-staging.AWSAdministratorAccess

# For production environment
export AWS_PROFILE=carecar-hq-prod.AWSAdministratorAccess
```

### SSH and SCP via SSM

Once authenticated, use standard SSH commands with instance IDs or configured aliases:

#### Direct Instance Access

```bash
# SSH to an instance
ssh i-0123456789abcdef0

# Copy files to instance
scp local-file.txt i-0123456789abcdef0:/tmp/

# Copy files from instance
scp i-0123456789abcdef0:/var/log/app.log ./logs/

# Recursive copy
scp -r i-0123456789abcdef0:/home/ubuntu/backups/ ./local-backups/
```

#### CareCar Environment Aliases

```bash
# Connect to acceptance bastion
ssh carecar-acceptance-bastion

# Connect to production bastion (requires prod credentials)
ssh carecar-prod-bastion

# Copy files using aliases
scp deployment-script.sh carecar-acceptance-bastion:/tmp/
```

### Database Tunneling (CareCar Only)

The module provides convenient functions for database access via port forwarding:

#### Acceptance Database

```bash
carecar-acceptance-db
```

This:
1. Authenticates with `carecar-hq-staging` role
2. Finds the latest bastion instance
3. Opens a tunnel to the acceptance database on `localhost:5434`

Connect with your database client:
```bash
psql -h localhost -p 5434 -U your_username -d acceptance_db
```

#### Production Database

```bash
carecar-prod-db
```

This:
1. Authenticates with `carecar-hq-prod` role
2. Finds the latest bastion instance
3. Opens a tunnel to the production database on `localhost:5433`

**⚠️ WARNING**: This provides access to production data. Use with extreme caution.

Connect with your database client:
```bash
psql -h localhost -p 5433 -U your_username -d production_db
```

#### Generic Bastion Session

For interactive shell access to bastion hosts:

```bash
# Connect to staging bastion
carecar-ssm-bastion staging

# Connect to production bastion
carecar-ssm-bastion prod
```

### Quick Aliases

The module provides shell aliases for common operations:

```bash
# Set staging profile
aws-carecar-staging

# Set production profile
aws-carecar-prod
```

These are shortcuts for setting the AWS_PROFILE environment variable.

## Advanced Usage

### Finding Instance IDs

Get instance IDs programmatically:

```bash
# List all running instances with names
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Get specific instance by name
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bastion" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

ssh $INSTANCE_ID
```

### Direct SSM Sessions

For interactive SSM sessions without SSH:

```bash
aws ssm start-session --target i-0123456789abcdef0
```

### Custom Port Forwarding

Forward arbitrary ports through SSM:

```bash
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="internal-service.example.com",portNumber="8080",localPortNumber="8080"
```

## Troubleshooting

### "Session Manager plugin is not found"

Ensure the module is enabled and your configuration is rebuilt:

```bash
# Verify installation
which session-manager-plugin

# Should show: /nix/store/.../bin/session-manager-plugin
```

### "An error occurred (TargetNotConnected)"

The EC2 instance may not have the SSM agent running or lacks proper IAM permissions. Contact infrastructure team.

### "Unable to locate credentials"

You need to login to AWS SSO and set your profile:

```bash
aws sso login --sso-session carecar
export AWS_PROFILE=carecar-hq-staging.AWSAdministratorAccess
```

### "Could not connect to the endpoint URL"

Verify you're using the correct AWS region:

```bash
# CareCar infrastructure is in us-west-2
export AWS_DEFAULT_REGION=us-west-2
aws sts get-caller-identity
```

### SSH Connection Hangs

The ProxyCommand may be failing silently. Debug with verbose SSH:

```bash
ssh -vvv i-0123456789abcdef0
```

Look for errors in the ProxyCommand execution.

### SSO Session Expired

SSO sessions expire after a period. Re-login:

```bash
aws sso login --sso-session carecar
```

## Security Considerations

### MFA Requirements

- **Always required** for production access
- Tokens typically expire after 1-12 hours depending on configuration
- Use hardware MFA devices (YubiKey) or authenticator apps (1Password, Authy)

### Audit Logging

All SSM sessions are automatically logged to CloudWatch Logs:
- **Session start/end times**
- **Commands executed** (when configured)
- **User identity** (via AWS credentials)
- **Source IP address**

These logs are retained according to company policy and available for security audits.

### Best Practices

1. **Never share AWS credentials** - Each user must have their own IAM identity
2. **Use MFA everywhere** - Especially for production access
3. **Minimize session duration** - Authenticate only when needed
4. **Rotate credentials regularly** - Follow company security policies
5. **Use least privilege** - Only request roles you need for the task
6. **Verify environment** - Double-check before connecting to production

### Production Access Warning

Database tunnels and SSH access to production systems provide direct access to sensitive data:

- **Verify the environment** before connecting
- **Document your actions** when accessing production
- **Follow change management** procedures for production changes
- **Never test or experiment** in production environments
- **Use read-only access** when possible

## Architecture

### SSH ProxyCommand Flow

```
ssh i-instance-id
  ↓
SSH ProxyCommand (configured in ~/.ssh/config)
  ↓
aws ssm start-session --target i-instance-id --document-name AWS-StartSSHSession
  ↓
AWS Systems Manager Session Manager
  ↓
SSM Agent on EC2 Instance (outbound connection)
  ↓
SSH connection established
```

### Database Tunnel Flow

```
carecar-acceptance-db
  ↓
Set AWS_PROFILE (uses cached SSO credentials)
  ↓
Find bastion instance ID
  ↓
aws ssm start-session with port forwarding document
  ↓
SSM Agent on bastion
  ↓
Forward traffic to RDS endpoint
  ↓
Database accessible on localhost:5434
```

## Module Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `programs.aws-ssm.enable` | boolean | `false` | Enable AWS SSM configuration |
| `programs.aws-ssm.enableSshProxy` | boolean | `true` | Configure SSH ProxyCommand for SSM |
| `programs.aws-ssm.enableCareCar` | boolean | `false` | Enable CareCar-specific features |

## Related Documentation

- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [AWS Session Manager Plugin Installation](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- [awsume Documentation](https://awsu.me/)
- [CareCar Infrastructure Repository](https://github.com/CareCarInc/infrastructure)

## Support

For issues related to:
- **Module configuration**: Check this README and module source code
- **AWS credentials**: Contact your AWS administrator or review Okta setup
- **Infrastructure access**: Check with the infrastructure team
- **CareCar-specific issues**: Refer to the CareCar infrastructure repository

## Contributing

When modifying this module:

1. Test changes on a non-production system first
2. Update this README with any new features or usage patterns
3. Follow the repository's contribution guidelines
4. Ensure `nix flake check` passes before committing
