# USPS Odoo Module Development Plan - Nix Integration

## Executive Summary

This document provides a comprehensive plan for developing the USPS shipping integration module for Odoo v19 in a **separate GitHub repository** with full **Nix integration** into the goodlab homelab environment. The module will be developed with a Nix-based development environment and deployed to the noir server running Odoo in Docker.

**Key Objectives**:
1. Create a separate GitHub repository for the USPS module
2. Provide a Nix flake-based development environment
3. Integrate the module with the existing goodlab infrastructure
4. Enable hot-reloading during development
5. Support automated testing and CI/CD
6. Deploy seamlessly to noir's Odoo instance

---

## Table of Contents

1. [Repository Architecture](#repository-architecture)
2. [Development Environment Setup](#development-environment-setup)
3. [Nix Integration Strategy](#nix-integration-strategy)
4. [Development Workflow](#development-workflow)
5. [Testing Strategy](#testing-strategy)
6. [Deployment Pipeline](#deployment-pipeline)
7. [Integration with goodlab](#integration-with-goodlab)
8. [Local Development](#local-development)
9. [CI/CD Pipeline](#cicd-pipeline)
10. [Troubleshooting](#troubleshooting)

---

## Repository Architecture

### New Repository: `odoo-usps-shipping`

**Repository Structure**:

```
odoo-usps-shipping/
├── flake.nix                          # Nix flake for dev environment
├── flake.lock                         # Locked dependencies
├── README.md                          # Project documentation
├── LICENSE                            # AGPL-3.0 or LGPL-3.0
├── .github/
│   └── workflows/
│       ├── test.yml                   # Run tests on PR/push
│       ├── lint.yml                   # Code quality checks
│       └── release.yml                # Build and release
├── .gitignore                         # Python, Nix, Odoo artifacts
├── shell.nix                          # Legacy nix-shell support
├── default.nix                        # Default package
├── delivery_usps/                     # The actual Odoo module
│   ├── __init__.py
│   ├── __manifest__.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── delivery_carrier.py
│   │   ├── stock_picking.py
│   │   ├── usps_service.py
│   │   └── res_company.py
│   ├── wizards/
│   │   ├── __init__.py
│   │   └── choose_delivery_package.py
│   ├── views/
│   │   ├── delivery_carrier_views.xml
│   │   ├── stock_picking_views.xml
│   │   └── res_config_settings_views.xml
│   ├── data/
│   │   ├── delivery_usps_data.xml
│   │   └── ir_cron_data.xml
│   ├── static/
│   │   └── description/
│   │       ├── icon.png
│   │       ├── index.html
│   │       └── banner.png
│   ├── security/
│   │   └── ir.model.access.csv
│   └── lib/
│       ├── __init__.py
│       ├── usps_request.py
│       ├── usps_auth.py
│       └── usps_response.py
├── tests/                             # Tests outside module for dev
│   ├── __init__.py
│   ├── conftest.py                    # Pytest configuration
│   ├── test_usps_auth.py
│   ├── test_usps_rate.py
│   ├── test_usps_label.py
│   ├── test_usps_tracking.py
│   └── test_usps_address.py
├── docs/
│   ├── INSTALLATION.md
│   ├── CONFIGURATION.md
│   ├── API_REFERENCE.md
│   ├── DEVELOPMENT.md
│   └── CHANGELOG.md
├── scripts/
│   ├── setup-dev.sh                   # Quick dev setup
│   ├── run-tests.sh                   # Test runner
│   ├── build-module.sh                # Package module
│   └── deploy.sh                      # Deploy to server
├── nix/
│   ├── odoo.nix                       # Odoo package
│   ├── python-packages.nix            # Python dependencies
│   └── test-env.nix                   # Test environment
├── pyproject.toml                     # Python project metadata
├── pytest.ini                         # Pytest configuration
├── .pre-commit-config.yaml            # Pre-commit hooks
└── VERSION                            # Version file

```

### Repository URL Structure

```
GitHub Organization: orther (or create new org like "research-relay")
Repository Name: odoo-usps-shipping
Full URL: https://github.com/orther/odoo-usps-shipping
Branch Strategy: main (stable), develop (active development)
```

---

## Development Environment Setup

### Nix Flake Definition

**File: `flake.nix`** (in new repo)

```nix
{
  description = "USPS Shipping Integration for Odoo v19";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    # For Odoo package
    odoo-nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    systems,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;

      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: let
        # Python version matching Odoo v19 requirements
        python = pkgs.python311;

        # Odoo dependencies
        odooPackages = python.pkgs.buildPythonPackage rec {
          pname = "odoo";
          version = "19.0";

          src = pkgs.fetchFromGitHub {
            owner = "odoo";
            repo = "odoo";
            rev = "19.0";
            sha256 = "..."; # Update with actual hash
          };

          # Odoo dependencies (from requirements.txt)
          propagatedBuildInputs = with python.pkgs; [
            babel
            chardet
            cryptography
            decorator
            docutils
            ebaysdk
            freezegun
            gevent
            greenlet
            idna
            jinja2
            libsass
            lxml
            markupsafe
            num2words
            ofxparse
            passlib
            pillow
            polib
            psutil
            psycopg2
            pydot
            pyopenssl
            pypdf2
            pyserial
            python-dateutil
            python-ldap
            python-stdnum
            pytz
            pyusb
            qrcode
            reportlab
            requests
            urllib3
            vobject
            werkzeug
            xlrd
            xlsxwriter
            xlwt
            zeep
          ];

          doCheck = false;
        };

        # Additional dependencies for USPS module
        uspsModuleDeps = with python.pkgs; [
          requests
          python-dateutil
          pytz
        ];

        # Development tools
        devTools = with pkgs; [
          # Odoo development
          nodejs_20
          postgresql_16

          # Python development
          python.pkgs.pip
          python.pkgs.setuptools
          python.pkgs.wheel
          python.pkgs.ipython
          python.pkgs.ipdb

          # Testing
          python.pkgs.pytest
          python.pkgs.pytest-cov
          python.pkgs.pytest-mock
          python.pkgs.pytest-xdist
          python.pkgs.faker

          # Code quality
          python.pkgs.black
          python.pkgs.isort
          python.pkgs.flake8
          python.pkgs.pylint
          python.pkgs.mypy

          # Development utilities
          git
          just
          watchexec
          entr
          httpie
          jq
        ];

        # The USPS module package
        uspsModule = python.pkgs.buildPythonPackage {
          pname = "odoo-usps-shipping";
          version = builtins.readFile ./VERSION;

          src = ./.;

          propagatedBuildInputs = uspsModuleDeps;

          doCheck = true;
          checkInputs = with python.pkgs; [
            pytest
            pytest-cov
            pytest-mock
          ];

          # Copy module to Odoo addons format
          installPhase = ''
            mkdir -p $out/lib/python${python.pythonVersion}/site-packages
            cp -r delivery_usps $out/lib/python${python.pythonVersion}/site-packages/
          '';

          meta = with pkgs.lib; {
            description = "USPS Shipping Integration for Odoo v19";
            homepage = "https://github.com/orther/odoo-usps-shipping";
            license = licenses.agpl3;
          };
        };

      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = [
            python
            odooPackages
            uspsModule
          ] ++ uspsModuleDeps ++ devTools;

          shellHook = ''
            echo "🚀 USPS Odoo Module Development Environment"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Python: ${python.version}"
            echo "Odoo: 19.0"
            echo ""
            echo "Available commands:"
            echo "  just run       - Start local Odoo instance"
            echo "  just test      - Run test suite"
            echo "  just lint      - Run linters"
            echo "  just fmt       - Format code"
            echo "  just watch     - Watch mode for development"
            echo ""
            echo "Database:"
            echo "  PostgreSQL: localhost:5432"
            echo "  Database: odoo_dev"
            echo ""

            # Set up Python path to include the module
            export PYTHONPATH="${self}/delivery_usps:$PYTHONPATH"

            # Set up Odoo config
            export ODOO_RC="${self}/.odoorc"

            # Create .odoorc if it doesn't exist
            if [ ! -f .odoorc ]; then
              cat > .odoorc <<EOF
            [options]
            admin_passwd = admin
            db_host = localhost
            db_port = 5432
            db_user = odoo
            db_password = odoo
            addons_path = ${self}/delivery_usps,${odooPackages}/lib/python${python.pythonVersion}/site-packages/odoo/addons
            http_port = 8069
            logfile = False
            log_level = debug
            EOF
            fi

            echo "Ready to develop! 🎉"
          '';
        };

        # Package output
        packages = {
          default = uspsModule;
          odoo-usps-shipping = uspsModule;
        };

        # Apps for running services
        apps = {
          # Run Odoo with the module
          odoo = {
            type = "app";
            program = "${pkgs.writeShellScript "run-odoo" ''
              ${odooPackages}/bin/odoo \
                --config=${self}/.odoorc \
                --addons-path=${self}/delivery_usps,${odooPackages}/addons \
                --dev=all \
                --log-level=debug
            ''}";
          };

          # Run tests
          test = {
            type = "app";
            program = "${pkgs.writeShellScript "run-tests" ''
              ${python}/bin/pytest tests/ -v --cov=delivery_usps --cov-report=html
            ''}";
          };
        };

        # Formatter
        formatter = pkgs.alejandra;
      };
    };
}
```

### Justfile for Common Tasks

**File: `justfile`** (in new repo)

```make
# Show available commands
default:
    @just --list

# Start local Odoo instance
run:
    nix run .#odoo

# Run test suite
test:
    nix run .#test

# Run tests in watch mode
test-watch:
    watchexec -e py -r 'just test'

# Lint code
lint:
    black --check delivery_usps tests
    isort --check delivery_usps tests
    flake8 delivery_usps tests
    pylint delivery_usps

# Format code
fmt:
    black delivery_usps tests
    isort delivery_usps tests
    nix fmt

# Type check
typecheck:
    mypy delivery_usps

# Run all checks (lint + test)
check: lint test typecheck

# Start PostgreSQL for development
db-start:
    docker run -d \
      --name odoo-postgres \
      -e POSTGRES_USER=odoo \
      -e POSTGRES_PASSWORD=odoo \
      -e POSTGRES_DB=odoo_dev \
      -p 5432:5432 \
      postgres:16

# Stop PostgreSQL
db-stop:
    docker stop odoo-postgres
    docker rm odoo-postgres

# Reset database
db-reset:
    docker exec odoo-postgres psql -U odoo -c "DROP DATABASE IF EXISTS odoo_dev;"
    docker exec odoo-postgres psql -U odoo -c "CREATE DATABASE odoo_dev;"

# Build module package
build:
    nix build

# Update flake inputs
update:
    nix flake update

# Deploy to goodlab noir server
deploy:
    ./scripts/deploy.sh

# Open development shell
shell:
    nix develop

# Generate module documentation
docs:
    cd docs && mkdocs build

# Watch for changes and reload Odoo
watch:
    watchexec -e py -r 'pkill -f "odoo-bin" && sleep 1 && just run'
```

---

## Nix Integration Strategy

### Integration with goodlab Repository

**Step 1: Add as Flake Input**

In `goodlab/flake.nix`, add the USPS module as an input:

```nix
inputs = {
  # ... existing inputs ...

  odoo-usps-shipping = {
    url = "github:orther/odoo-usps-shipping";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

**Step 2: Create Odoo Addons Path**

In `goodlab/services/research-relay/odoo.nix`, configure custom addons:

```nix
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.researchRelay.odoo;

  # Build custom addons path including USPS module
  customAddons = pkgs.symlinkJoin {
    name = "odoo-custom-addons";
    paths = [
      # USPS shipping module
      inputs.odoo-usps-shipping.packages.${pkgs.system}.default

      # Add other custom modules here
    ];
  };

in {
  # ... existing configuration ...

  # Add custom addons to Docker mount
  virtualisation.oci-containers.containers.odoo = {
    volumes = [
      "${customAddons}:/mnt/custom-addons:ro"
      # ... other mounts ...
    ];

    environment = {
      ADDONS_PATH = "/mnt/extra-addons,/mnt/custom-addons";
    };
  };
}
```

**Step 3: Enable Module in Configuration**

Add module configuration options:

```nix
# In services/research-relay/odoo.nix

options = {
  services.researchRelay.odoo = {
    enable = lib.mkEnableOption "Odoo service";

    uspsShipping = {
      enable = lib.mkEnableOption "USPS shipping integration";

      consumerKey = lib.mkOption {
        type = lib.types.str;
        description = "USPS OAuth Consumer Key";
      };

      consumerSecret = lib.mkOption {
        type = lib.types.str;
        description = "USPS OAuth Consumer Secret (stored in SOPS)";
      };

      accountNumber = lib.mkOption {
        type = lib.types.str;
        description = "USPS Ship account number";
      };

      prodEnvironment = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use production USPS API";
      };
    };
  };
};
```

**Step 4: Add Secrets**

In `secrets/research-relay.yaml` (SOPS encrypted):

```yaml
research-relay:
  usps:
    consumer-key: "YOUR_CONSUMER_KEY"
    consumer-secret: "YOUR_CONSUMER_SECRET"
    account-number: "YOUR_ACCOUNT_NUMBER"
```

In `services/research-relay/secrets.nix`:

```nix
sops.secrets = {
  # ... existing secrets ...

  "research-relay/usps/consumer-key" = {
    sopsFile = ../../secrets/research-relay.yaml;
    owner = "odoo";
    group = "odoo";
  };

  "research-relay/usps/consumer-secret" = {
    sopsFile = ../../secrets/research-relay.yaml;
    owner = "odoo";
    group = "odoo";
  };

  "research-relay/usps/account-number" = {
    sopsFile = ../../secrets/research-relay.yaml;
    owner = "odoo";
    group = "odoo";
  };
};
```

---

## Development Workflow

### Local Development Setup

**1. Clone Both Repositories**

```bash
# Main homelab repo
cd ~/Projects
git clone https://github.com/orther/goodlab.git
cd goodlab

# USPS module repo
cd ~/Projects
git clone https://github.com/orther/odoo-usps-shipping.git
cd odoo-usps-shipping
```

**2. Enter Development Shell**

```bash
cd ~/Projects/odoo-usps-shipping
nix develop
```

**3. Start Local PostgreSQL**

Option A: Use Docker
```bash
just db-start
```

Option B: Use goodlab's devservices
```bash
cd ~/Projects/goodlab
nix run .#devservices
```

**4. Initialize Odoo Database**

```bash
# From odoo-usps-shipping repo
odoo-bin -i base -d odoo_dev --stop-after-init
```

**5. Install USPS Module**

```bash
odoo-bin -i delivery_usps -d odoo_dev --stop-after-init
```

**6. Start Odoo with Auto-reload**

```bash
just run
# or
nix run .#odoo
```

Access at: http://localhost:8069

**7. Make Changes and Test**

Changes to Python files will trigger auto-reload (with `--dev=all` flag).

```bash
# In another terminal
just test-watch
```

### Development Cycle

```
1. Make code changes
   ↓
2. Tests auto-run (watch mode)
   ↓
3. Odoo auto-reloads (dev mode)
   ↓
4. Test in browser
   ↓
5. Commit changes
   ↓
6. Push to GitHub
   ↓
7. CI/CD runs tests
   ↓
8. Deploy to noir (if tests pass)
```

### Hot Module Reloading

**Enable Development Mode in Odoo**:

```bash
# Add to .odoorc or command line
--dev=all,reload,qweb,werkzeug,xml
```

**What gets auto-reloaded**:
- Python code changes
- XML views (with F5 refresh)
- CSV data files
- JavaScript/CSS (with browser refresh)

**What requires restart**:
- `__manifest__.py` changes
- Model schema changes (new fields)
- Database migrations

---

## Testing Strategy

### Test Environment Setup

**File: `tests/conftest.py`**

```python
import pytest
import os
from unittest.mock import MagicMock

# Mock Odoo environment for testing
@pytest.fixture
def odoo_env():
    """Mock Odoo environment"""
    env = MagicMock()
    env.cr = MagicMock()  # Database cursor
    env.uid = 1  # Admin user
    env.context = {}
    return env

@pytest.fixture
def delivery_carrier(odoo_env):
    """Mock delivery.carrier record"""
    carrier = MagicMock()
    carrier.env = odoo_env
    carrier.usps_consumer_key = os.getenv('USPS_CONSUMER_KEY', 'test_key')
    carrier.usps_consumer_secret = os.getenv('USPS_CONSUMER_SECRET', 'test_secret')
    carrier.prod_environment = False
    return carrier

@pytest.fixture
def usps_client():
    """Real USPS API client for integration tests"""
    from delivery_usps.lib.usps_request import USPSRequest

    consumer_key = os.getenv('USPS_TEST_KEY')
    consumer_secret = os.getenv('USPS_TEST_SECRET')

    if not consumer_key or not consumer_secret:
        pytest.skip("USPS test credentials not configured")

    return USPSRequest(consumer_key, consumer_secret, prod_environment=False)

@pytest.fixture
def mock_usps_responses():
    """Mock USPS API responses"""
    return {
        'rate_success': {
            'success': True,
            'price': 15.50,
            'service': 'PRIORITY_MAIL',
        },
        'label_success': {
            'success': True,
            'tracking_number': '9400111899562022425959',
            'label_data': b'%PDF-1.4...',  # Mock PDF data
        },
        'tracking_info': {
            'success': True,
            'status': 'Delivered',
            'events': [
                {
                    'date': '2025-11-06T10:30:00Z',
                    'status': 'Delivered',
                    'location': 'NEW YORK, NY 10014',
                }
            ],
        },
    }
```

### Test Types

**1. Unit Tests** (`tests/test_usps_*.py`)

```python
# tests/test_usps_auth.py
def test_oauth_token_retrieval(usps_client):
    """Test OAuth token can be retrieved"""
    token = usps_client._get_access_token()
    assert token is not None
    assert len(token) > 0

def test_token_caching(usps_client):
    """Test token is cached and reused"""
    token1 = usps_client._get_access_token()
    token2 = usps_client._get_access_token()
    assert token1 == token2
```

**2. Integration Tests** (with USPS test API)

```python
# tests/test_usps_rate.py
@pytest.mark.integration
def test_real_rate_calculation(usps_client):
    """Test rate calculation with real USPS API"""
    result = usps_client.get_rates(
        origin_zip='22407',
        dest_zip='10014',
        weight=5.0,
        dimensions={'length': 12, 'width': 10, 'height': 8},
        services=['PRIORITY_MAIL']
    )

    assert result['success']
    assert result['price'] > 0
```

**3. Odoo Integration Tests**

```python
# tests/test_odoo_integration.py
@pytest.mark.odoo
def test_rate_shipment_method(delivery_carrier, mock_usps_responses, mocker):
    """Test usps_rate_shipment method"""
    # Mock the USPS API call
    mocker.patch(
        'delivery_usps.models.delivery_carrier.USPSRequest.get_rates',
        return_value=mock_usps_responses['rate_success']
    )

    order = MagicMock()
    order.partner_shipping_id.zip = '10014'
    order.warehouse_id.partner_id.zip = '22407'

    result = delivery_carrier.usps_rate_shipment(order)

    assert result['success']
    assert result['price'] == 15.50
```

### Running Tests

```bash
# All tests
just test

# Unit tests only
pytest tests/ -m "not integration and not odoo"

# Integration tests (requires USPS test credentials)
export USPS_TEST_KEY="your_test_key"
export USPS_TEST_SECRET="your_test_secret"
pytest tests/ -m integration

# Watch mode
just test-watch

# Coverage report
pytest --cov=delivery_usps --cov-report=html
open htmlcov/index.html
```

---

## Deployment Pipeline

### Deployment to noir

**Automated Deployment Process**:

```
Developer pushes to main branch
    ↓
GitHub Actions runs tests
    ↓
Tests pass → Create new flake.lock
    ↓
goodlab repo updates odoo-usps-shipping input
    ↓
NixOS rebuild on noir
    ↓
Odoo container restarts with new module
    ↓
Module auto-upgraded in Odoo
```

### Manual Deployment Steps

**1. Update goodlab Flake Input**

```bash
cd ~/Projects/goodlab

# Update USPS module to latest
nix flake lock --update-input odoo-usps-shipping

# Commit the change
git add flake.lock
git commit -m "chore: update odoo-usps-shipping module"
git push
```

**2. Deploy to noir**

```bash
# From goodlab repo
just deploy noir

# Or if deploying remotely
just deploy noir 10.0.10.2  # Replace with actual IP
```

**3. Verify Deployment**

```bash
ssh orther@noir

# Check Odoo container is running
docker ps | grep odoo

# Check module is available
docker exec -it odoo odoo-bin -d odoo --stop-after-init --list

# Check logs
journalctl -u docker-odoo.service -f
```

**4. Upgrade Module in Odoo UI**

1. Navigate to https://research-relay.com or https://odoo.orther.dev
2. Login as admin
3. Go to Apps menu (Enable Developer Mode if needed)
4. Search for "USPS"
5. Click "Upgrade" if module is already installed
6. Or click "Install" if first time

### Rollback Procedure

If deployment fails:

```bash
# On noir
sudo nixos-rebuild switch --rollback

# Or revert the goodlab commit
cd ~/Projects/goodlab
git revert HEAD
git push
just deploy noir
```

---

## Integration with goodlab

### Directory Structure Changes

**In goodlab repository**:

```
goodlab/
├── flake.nix                          # Add odoo-usps-shipping input
├── flake.lock                         # Will include new input
├── services/
│   └── research-relay/
│       ├── odoo.nix                   # Update to include custom modules
│       ├── secrets.nix                # Add USPS secrets
│       └── default.nix                # Re-export configuration
└── secrets/
    └── research-relay.yaml            # Add USPS credentials (encrypted)
```

### Configuration Updates

**File: `goodlab/services/research-relay/odoo.nix`**

```nix
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.researchRelay.odoo;

  # Custom addons including USPS module
  customAddons = pkgs.symlinkJoin {
    name = "odoo-research-relay-addons";
    paths = lib.optionals cfg.uspsShipping.enable [
      inputs.odoo-usps-shipping.packages.${pkgs.system}.default
    ];
  };

  # Odoo configuration file
  odooConfig = pkgs.writeText "odoo.conf" ''
    [options]
    admin_passwd = ${config.sops.secrets."research-relay/odoo/admin-password".path}
    db_host = localhost
    db_port = 5432
    db_name = odoo
    db_user = odoo
    db_password = ${config.sops.secrets."research-relay/odoo/db-password".path}
    addons_path = /mnt/extra-addons${lib.optionalString cfg.uspsShipping.enable ",/mnt/custom-addons"}
    proxy_mode = True
    workers = 4
    max_cron_threads = 2

    ${lib.optionalString cfg.uspsShipping.enable ''
    # USPS Configuration (passed via environment)
    ''}
  '';

in {
  options.services.researchRelay.odoo = {
    enable = lib.mkEnableOption "Research Relay Odoo service";

    uspsShipping = {
      enable = lib.mkEnableOption "USPS shipping integration";

      prodEnvironment = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use USPS production API (vs test)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Add USPS secrets if enabled
    sops.secrets = lib.mkIf cfg.uspsShipping.enable {
      "research-relay/usps/consumer-key" = {
        sopsFile = ../../secrets/research-relay.yaml;
      };
      "research-relay/usps/consumer-secret" = {
        sopsFile = ../../secrets/research-relay.yaml;
      };
      "research-relay/usps/account-number" = {
        sopsFile = ../../secrets/research-relay.yaml;
      };
    };

    # Odoo Docker container
    virtualisation.oci-containers.containers.odoo = {
      image = "odoo:19.0";

      volumes = [
        "/var/lib/odoo/addons:/mnt/extra-addons"
        "/var/lib/odoo/data:/var/lib/odoo"
        "${odooConfig}:/etc/odoo/odoo.conf:ro"
      ] ++ lib.optionals cfg.uspsShipping.enable [
        "${customAddons}:/mnt/custom-addons:ro"
      ];

      environment = lib.mkMerge [
        {
          HOST = "localhost";
          PORT = "5432";
          USER = "odoo";
        }
        (lib.mkIf cfg.uspsShipping.enable {
          USPS_CONSUMER_KEY_FILE = config.sops.secrets."research-relay/usps/consumer-key".path;
          USPS_CONSUMER_SECRET_FILE = config.sops.secrets."research-relay/usps/consumer-secret".path;
          USPS_ACCOUNT_NUMBER_FILE = config.sops.secrets."research-relay/usps/account-number".path;
          USPS_PROD_ENVIRONMENT = if cfg.uspsShipping.prodEnvironment then "1" else "0";
        })
      ];

      ports = [ "127.0.0.1:8069:8069" ];

      dependsOn = [ "postgres" ];
    };
  };
}
```

**File: `goodlab/machines/noir/configuration.nix`**

```nix
# Enable USPS shipping module
services.researchRelay.odoo = {
  enable = true;

  uspsShipping = {
    enable = true;  # Set to true when ready
    prodEnvironment = false;  # Start with test environment
  };
};
```

---

## Local Development

### Complete Development Setup

**Step-by-Step Guide**:

```bash
# 1. Setup directories
mkdir -p ~/Projects
cd ~/Projects

# 2. Clone goodlab (if not already)
git clone https://github.com/orther/goodlab.git

# 3. Clone USPS module repo (once created)
git clone https://github.com/orther/odoo-usps-shipping.git

# 4. Enter USPS module dev environment
cd odoo-usps-shipping
nix develop

# 5. Start local PostgreSQL
just db-start

# 6. Configure USPS test credentials
export USPS_TEST_KEY="your_consumer_key_from_usps_portal"
export USPS_TEST_SECRET="your_consumer_secret_from_usps_portal"

# Or create .env file
cat > .env <<EOF
USPS_TEST_KEY=your_consumer_key
USPS_TEST_SECRET=your_consumer_secret
USPS_ACCOUNT_NUMBER=your_account_number
EOF

# 7. Initialize Odoo database
odoo-bin -i base -d odoo_dev --stop-after-init

# 8. Install USPS module
odoo-bin -i delivery_usps -d odoo_dev --stop-after-init

# 9. Start Odoo in development mode
just run

# Or manually:
odoo-bin --dev=all,reload \
  --addons-path=./delivery_usps,/nix/store/.../odoo/addons \
  -d odoo_dev

# 10. Open browser
open http://localhost:8069
```

### Development Tools

**VS Code / Cursor Configuration**

`.vscode/settings.json`:

```json
{
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.linting.flake8Enabled": true,
  "python.formatting.provider": "black",
  "python.testing.pytestEnabled": true,
  "python.testing.unittestEnabled": false,
  "editor.formatOnSave": true,
  "editor.rulers": [88],
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter"
  },
  "files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true
  }
}
```

**Direnv Integration** (optional)

`.envrc`:

```bash
use flake

# Load environment variables
dotenv_if_exists .env

# Set Python path
export PYTHONPATH="$PWD/delivery_usps:$PYTHONPATH"
```

### Database Management

**Backup local database**:

```bash
docker exec odoo-postgres pg_dump -U odoo odoo_dev | gzip > backup.sql.gz
```

**Restore from backup**:

```bash
gunzip -c backup.sql.gz | docker exec -i odoo-postgres psql -U odoo odoo_dev
```

**Clone production database** (for testing):

```bash
# SSH to noir and dump database
ssh orther@noir 'docker exec odoo-postgres pg_dump -U odoo odoo' | \
  docker exec -i odoo-postgres psql -U odoo odoo_dev
```

---

## CI/CD Pipeline

### GitHub Actions Workflows

**File: `.github/workflows/test.yml`**

```yaml
name: Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: DeterminateSystems/nix-installer-action@main

      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Run tests
        run: nix run .#test

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml

  lint:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: DeterminateSystems/nix-installer-action@main

      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Check formatting
        run: |
          nix develop --command black --check delivery_usps tests
          nix develop --command isort --check delivery_usps tests
          nix develop --command flake8 delivery_usps tests

      - name: Check Nix formatting
        run: nix fmt -- --check .
```

**File: `.github/workflows/release.yml`**

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: DeterminateSystems/nix-installer-action@main

      - name: Build package
        run: nix build

      - name: Create release
        uses: softprops/action-gh-release@v1
        with:
          files: result/lib/python3.11/site-packages/delivery_usps/**
          generate_release_notes: true
```

### Automated Deployment

**Option 1: Manual trigger after release**

```bash
# After new release is published on GitHub
cd ~/Projects/goodlab
nix flake lock --update-input odoo-usps-shipping
git commit -am "chore: update USPS module to vX.Y.Z"
git push
just deploy noir
```

**Option 2: Automated via GitHub Actions** (in goodlab repo)

```yaml
# .github/workflows/update-usps-module.yml
name: Update USPS Module

on:
  repository_dispatch:
    types: [usps-module-updated]

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: DeterminateSystems/nix-installer-action@main

      - name: Update flake input
        run: |
          nix flake lock --update-input odoo-usps-shipping
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git commit -am "chore: update USPS module"
          git push
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Module not found in Odoo

**Symptoms**: Module doesn't appear in Apps menu

**Solutions**:
```bash
# 1. Check addons path
docker exec -it odoo cat /etc/odoo/odoo.conf | grep addons_path

# 2. Verify module is mounted
docker exec -it odoo ls -la /mnt/custom-addons/delivery_usps

# 3. Update apps list
docker exec -it odoo odoo-bin -u delivery_usps -d odoo --stop-after-init

# 4. Check logs
journalctl -u docker-odoo.service -n 100
```

#### Issue 2: Import errors

**Symptoms**: Python import errors when starting Odoo

**Solutions**:
```bash
# 1. Check Python dependencies
nix develop --command python -c "import requests; import dateutil"

# 2. Verify module structure
ls -R delivery_usps/

# 3. Check __init__.py files exist
find delivery_usps -name "__init__.py"
```

#### Issue 3: USPS API authentication fails

**Symptoms**: "Authentication failed" errors in logs

**Solutions**:
```bash
# 1. Verify credentials are set
cat /run/secrets/research-relay/usps/consumer-key

# 2. Test OAuth token manually
curl -X POST https://apis-tem.usps.com/oauth2/v3/token \
  -H "Content-Type: application/json" \
  -d "{\"client_id\":\"$KEY\",\"client_secret\":\"$SECRET\",\"grant_type\":\"client_credentials\"}"

# 3. Check Odoo logs for detailed error
docker logs -f odoo 2>&1 | grep -i usps
```

#### Issue 4: Development changes not reflected

**Symptoms**: Code changes don't appear in running Odoo

**Solutions**:
```bash
# 1. Ensure --dev=all flag is set
ps aux | grep odoo-bin

# 2. Manually restart Odoo
pkill -f odoo-bin
just run

# 3. Clear Python cache
find delivery_usps -type d -name __pycache__ -exec rm -r {} +
```

#### Issue 5: Database migration fails

**Symptoms**: Module upgrade fails with schema errors

**Solutions**:
```bash
# 1. Backup database first
docker exec odoo-postgres pg_dump -U odoo odoo > backup.sql

# 2. Drop and reinstall module
docker exec -it odoo odoo-bin -d odoo --stop-after-init \
  --uninstall delivery_usps

docker exec -it odoo odoo-bin -d odoo --stop-after-init \
  --install delivery_usps

# 3. If still fails, check PostgreSQL logs
docker logs odoo-postgres
```

### Debug Mode

**Enable comprehensive debugging**:

```bash
# In .odoorc or command line
odoo-bin \
  --dev=all,reload,qweb,werkzeug,xml \
  --log-level=debug \
  --log-handler=delivery_usps:DEBUG \
  -d odoo_dev
```

**Check what's being logged**:

```python
# In delivery_usps code
import logging
_logger = logging.getLogger(__name__)

_logger.debug('USPS API request: %s', data)
_logger.info('USPS rate calculated: %s', rate)
_logger.error('USPS API error: %s', error)
```

---

## Next Steps

### Week 1: Repository Setup

**Day 1-2: Create Repository**
- [ ] Create GitHub repo: `odoo-usps-shipping`
- [ ] Initialize with README, LICENSE (AGPL-3.0)
- [ ] Set up basic directory structure
- [ ] Create initial `flake.nix`
- [ ] Add `.gitignore` for Python/Nix

**Day 3-4: Nix Environment**
- [ ] Complete Nix flake with all dependencies
- [ ] Create `justfile` for common tasks
- [ ] Test development shell works
- [ ] Document setup in README

**Day 5: Integration Planning**
- [ ] Add repo as input to goodlab flake
- [ ] Configure odoo.nix for custom addons
- [ ] Set up SOPS secrets structure
- [ ] Test deployment to noir (with dummy module)

### Week 2: Development Foundation

**Day 1-2: Module Scaffold**
- [ ] Create basic module structure
- [ ] Write `__manifest__.py`
- [ ] Set up models with minimal fields
- [ ] Create basic views

**Day 3-4: API Client**
- [ ] Implement OAuth 2.0 authentication
- [ ] Create USPSRequest base class
- [ ] Add token caching
- [ ] Write tests for auth

**Day 5: Testing Setup**
- [ ] Configure pytest
- [ ] Write test fixtures
- [ ] Set up CI/CD pipeline
- [ ] Run first tests

### Week 3-13: Feature Development

Follow the 8-phase plan from USPS_ODOO_INTEGRATION_PLAN.md:

1. **Phase 1**: Foundation (Weeks 3-4) - OAuth, config, base structure
2. **Phase 2**: Rate Calculation (Weeks 5-6) - Pricing API integration
3. **Phase 3**: Address Validation (Week 7) - Address API
4. **Phase 4**: Label Generation (Weeks 8-10) - Labels API
5. **Phase 5**: Tracking (Week 11) - Tracking API
6. **Phase 6**: Advanced Features (Weeks 12-13) - Insurance, returns, etc.
7. **Phase 7**: Testing & Docs (Week 14) - Comprehensive testing
8. **Phase 8**: Production (Week 15) - Production deployment

---

## Summary

This plan provides a complete development and deployment strategy for the USPS Odoo module:

**Key Components**:
1. ✅ **Separate Repository**: Full Nix flake for independent development
2. ✅ **Development Environment**: Nix shell with Odoo, PostgreSQL, all tools
3. ✅ **Integration**: Flake input in goodlab, seamless deployment
4. ✅ **Testing**: pytest, CI/CD, integration tests
5. ✅ **Deployment**: Automated pipeline from GitHub to noir
6. ✅ **Documentation**: Comprehensive guides for all scenarios

**Workflow Summary**:
```
Develop locally (odoo-usps-shipping repo)
    ↓
Test with nix develop + just test
    ↓
Commit and push to GitHub
    ↓
CI/CD runs tests
    ↓
Update goodlab flake input
    ↓
Deploy to noir with just deploy noir
    ↓
Module available in Odoo
```

**Benefits of This Approach**:
- 🔒 **Reproducible**: Everything defined in Nix
- 🚀 **Fast iteration**: Hot reloading during development
- 🧪 **Well-tested**: Unit, integration, and Odoo tests
- 📦 **Easy deployment**: Single command deploys to noir
- 🔐 **Secure**: Secrets managed with SOPS
- 📚 **Documented**: Clear guides for all scenarios

Ready to start implementation! 🎉

---

**Document Version**: 1.0
**Last Updated**: 2025-11-06
**Author**: Claude (Anthropic)
**Related**: USPS_ODOO_INTEGRATION_PLAN.md
