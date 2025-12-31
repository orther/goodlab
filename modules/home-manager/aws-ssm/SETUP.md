# AWS SSM Setup Guide

Quick start guide for setting up AWS Systems Manager access to CareCar infrastructure.

## Prerequisites

- The `aws-ssm` module must be enabled in your nix configuration and deployed
- You must have AWS account access to CareCar infrastructure
- Okta SSO must be configured for AWS access
- MFA device enrolled for production access

## One-Time Setup

### Step 1: Configure awsume

Initialize awsume configuration:

```bash
awsume-configure
```

Accept the default settings when prompted. This creates `~/.awsume/config.yaml`.

### Step 2: Configure AWS SSO

Set up AWS Single Sign-On with CareCar:

```bash
aws configure sso
```

Answer the prompts:
- **SSO session name**: `carecar` (or any name you prefer)
- **SSO start URL**: `https://carecar.awsapps.com/start/`
- **SSO region**: `us-west-2`
- **SSO registration scopes**: Press Enter for default
- **CLI default client Region**: `us-west-2`
- **CLI default output format**: `json` (or your preference)
- **CLI profile name**: `carecar-staging` (or any descriptive name)

A browser window will open for Okta authentication.

### Step 3: Populate All Available Profiles

Automatically configure all CareCar AWS accounts you have access to:

```bash
aws-sso-util configure populate -u https://carecar.awsapps.com/start/
```

This discovers and configures profiles for all accessible accounts and roles:
- `carecar-hq-staging.AWSAdministratorAccess`
- `carecar-hq-prod.AWSAdministratorAccess`
- And any other accounts you have access to

### Step 4: Verify Setup

List configured profiles:

```bash
aws configure list-profiles | grep carecar
```

You should see multiple `carecar-*` profiles.

Test authentication:

```bash
awsume carecar-hq-staging.AWSAdministratorAccess --region us-west-2
aws sts get-caller-identity
```

If successful, you'll see your AWS identity information.

## Usage

### Authentication Required Before Each Session

SSM requires active AWS credentials. Authenticate before using any SSM features:

```bash
# For staging environment
awsume carecar-hq-staging.AWSAdministratorAccess --region us-west-2

# For production environment (requires MFA)
awsume carecar-hq-prod.AWSAdministratorAccess --region us-west-2
```

**Shortcut aliases:**
```bash
awsume-carecar-staging  # Staging authentication
awsume-carecar-prod     # Production authentication
```

### SSH to EC2 Instances

After authentication, use standard SSH commands:

```bash
# SSH using instance ID
ssh i-0123456789abcdef0

# SSH using environment alias
ssh carecar-acceptance-bastion
ssh carecar-prod-bastion

# Copy files to instance
scp local-file.txt i-0123456789abcdef0:/tmp/

# Copy files from instance
scp i-0123456789abcdef0:/var/log/app.log ./logs/
```

### Database Tunneling

#### Acceptance Database

```bash
carecar-acceptance-db
```

This:
1. Authenticates with staging credentials
2. Establishes tunnel to acceptance database on `localhost:5434`
3. Keeps the tunnel open (use Ctrl+C to close)

Connect with your database client:
```bash
psql -h localhost -p 5434 -U your_username -d database_name
```

#### Production Database

```bash
carecar-prod-db
```

This:
1. Authenticates with production credentials (MFA required)
2. Establishes tunnel to production database on `localhost:5433`
3. Keeps the tunnel open (use Ctrl+C to close)

**⚠️ WARNING**: This provides access to production data. Use with extreme caution.

Connect with your database client:
```bash
psql -h localhost -p 5433 -U your_username -d database_name
```

### Interactive Bastion Sessions

For command-line access to bastion hosts:

```bash
# Staging bastion
carecar-ssm-bastion staging

# Production bastion
carecar-ssm-bastion prod
```

## Common Workflows

### Accessing Staging Infrastructure

```bash
# 1. Authenticate
awsume-carecar-staging

# 2. Use any of these features:
ssh carecar-acceptance-bastion        # Interactive SSH
carecar-acceptance-db                 # Database tunnel
ssh i-<instance-id>                   # Direct instance access
scp file.txt i-<instance-id>:/tmp/    # File transfer
```

### Accessing Production Infrastructure

```bash
# 1. Authenticate (requires MFA)
awsume-carecar-prod

# 2. Use production features:
ssh carecar-prod-bastion              # Interactive SSH
carecar-prod-db                       # Database tunnel (⚠️ PRODUCTION)
```

### Finding Instance IDs

```bash
# List all running instances with names
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Get specific instance by name tag
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=bastion" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text
```

## Troubleshooting

### "Unable to locate credentials"

You forgot to authenticate with `awsume`:

```bash
awsume carecar-hq-staging.AWSAdministratorAccess --region us-west-2
```

### "Session Manager plugin is not found"

The plugin should be installed automatically. Verify:

```bash
which ssm-session-manager-plugin
```

If missing, rebuild your configuration:
```bash
just deploy nblap
```

### "An error occurred (TargetNotConnected)"

The EC2 instance may not have SSM agent running or lacks IAM permissions. Contact the infrastructure team.

### "Could not connect to the endpoint URL"

Ensure you're using the correct AWS region:

```bash
export AWS_DEFAULT_REGION=us-west-2
awsume carecar-hq-staging.AWSAdministratorAccess --region us-west-2
```

### SSH Connection Hangs

Debug with verbose SSH output:

```bash
ssh -vvv i-0123456789abcdef0
```

Check the ProxyCommand execution output for errors.

### MFA Token Expired

Tokens expire after a period. Re-authenticate:

```bash
awsume carecar-hq-staging.AWSAdministratorAccess --region us-west-2
```

For automatic renewal, use:
```bash
awsume --auto-refresh carecar-hq-staging.AWSAdministratorAccess --region us-west-2
```

## Security Best Practices

1. **Always verify the environment** before connecting
2. **Use MFA** for all production access
3. **Close database tunnels** when not in use (Ctrl+C)
4. **Re-authenticate** when switching between staging and production
5. **Never share AWS credentials** - each user must have their own
6. **Document production access** according to company policy

## Additional Resources

- [Full Documentation](./README.md) - Comprehensive guide with architecture details
- [CareCar Infrastructure Repo](https://github.com/CareCarInc/infrastructure) - Infrastructure documentation
- [AWS Systems Manager Docs](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) - Official AWS documentation

## Support

For issues:
- **Module configuration**: See [README.md](./README.md)
- **AWS credentials**: Contact your AWS administrator or review Okta setup
- **Infrastructure access**: Contact the infrastructure team
- **CareCar-specific issues**: See CareCar infrastructure repository
