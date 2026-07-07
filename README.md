# Tanzu Platform Cloud Foundry Configuration Repository

This repository contains Windows-based automation scripts and configurations for managing VMware Tanzu Platform for Cloud Foundry deployments using OM CLI.

## Platform Support

**Primary Platform:** Windows (`.bat` batch scripts)

All automation scripts are Windows batch files designed to run on:
- Windows 10/11
- Windows Server 2016+
- Windows jumphost environments

**Alternative Platforms:** The documentation references some Linux/Mac commands for SSH and certificate generation, but the core automation is Windows-based. 

## Prerequisites

**Before using this repository, you must have:**

### ✅ Ops Manager Deployed

This repository **requires** a running Ops Manager instance. You must deploy Ops Manager before proceeding with any automation scripts.

📖 **[Deploy Ops Manager on vSphere](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/tanzu-operations-manager/3-2/tanzu-ops-manager/vsphere-deploy.html)**

**Critical information to document:**
- ✓ Ops Manager URL/IP address
- ✓ Admin username and password
- ✓ **Decryption passphrase** (⚠️ Store securely - cannot be recovered!)
- ✓ SSH private key

**See:** [docs/installation/GETTING-STARTED.md - Phase 0](docs/installation/GETTING-STARTED.md#phase-0-deploy-ops-manager-prerequisite) for detailed deployment guidance.

### ✅ Network Access

From your jumphost, you need connectivity to:
- Ops Manager: TCP 443
- BOSH Director: TCP 25555, 8443, 8844 (after Director deployment)
- vCenter: TCP 443

### ✅ Credentials Ready

You'll need credentials for:
- Ops Manager (admin username/password)
- vCenter (username/password)
- Network configuration (IP ranges, gateways, DNS)

---

## 📚 Documentation

Complete documentation is organized by lifecycle phase:

### 🚀 Installation & Setup

Get started with setting up your jumphost and deploying your first foundation.

- **[Getting Started Guide](docs/installation/GETTING-STARTED.md)** - Complete end-to-end workflow from jumphost setup through first deployment (includes detailed CLI tool installation for Windows, Mac, and Linux)
- **[Variables Collection Checklist](docs/installation/VARIABLES-CHECKLIST.md)** - Systematic worksheet to collect all required variables for your environment

### ⚙️ Operations & Maintenance

Day-to-day operational procedures and credential management.

- **[Troubleshooting Guide](docs/troubleshooting.md)** - Common issues and solutions

### 🔄 Temporary Shutdown

Procedures for temporarily stopping a foundation for maintenance.


## Repository Structure (Multi-Foundation Architecture)

```
tpcf-platform-automation/
├── env-creds/                # Multi-foundation credentials
│   ├── sandbox/              # Sandbox environment
│   │   └── om-env-redacted.yml           # Ops Manager connection (template)
│   └── production/           # Production environment
│       └── om-env-redacted.yml           # Ops Manager connection (template)
│
├── ops-scripts/              # Windows automation scripts
│   ├── om-command.bat                    # Core OM CLI wrapper
│   ├── verify-prerequisites.bat          # Check required tools
│   ├── configure-director.bat            # Configure BOSH Director
│   ├── configure-product.bat             # Configure TAS/products
│   ├── apply-changes.bat                 # Apply changes to foundation
│   ├── upload-product.bat                # Upload product tiles
│   ├── stage-product.bat                 # Stage uploaded products
│   ├── backup-foundation-config.bat      # Backup configurations
│   └── test-om-interpolation.bat         # Test OM interpolation
│
├── certs/                    # SSL certificate management
│   ├── generate-openssl-certs-sbx.md     # Sandbox cert generation guide
│   ├── generate-openssl-certs-prod.md    # Production cert generation guide
│   ├── wildcard-cert-req-sbx-redacted.cnf
│   └── wildcard-cert-req-prod-redacted.cnf
│
├── docs/                     # Documentation
│   └── installation/         # Setup and installation guides
│
├── config-backup/            # Automated backups (gitignored)
│
├── foundation-setup-redacted.bat         # Foundation setup script
└── create-orgs-spaces-redacted.bat       # Org/space creation script
```

## Configuration Architecture

This repository uses a **foundation-based configuration** approach:

### 1. Foundation Credentials (env-creds/<foundation>/om-env-redacted.yml)
- Contains Ops Manager connection details for each foundation
- Includes target URL, authentication credentials, and SSL settings
- Template files provided - copy and customize with actual values

## Prerequisites - Installing CLI Tools

These tools are required on your jumphost to run the automation scripts.

### Required Tools

1. **OM CLI** - Ops Manager automation
2. **CF CLI** - Cloud Foundry/TAS management (post-deployment)
3. **jq** - JSON processing (used by scripts)
4. **git** - Version control (required if managing configs in source control)
5. **UAAC** - UAA client for user management

---

### Installation Guides

All installation instructions (Windows, Mac, Linux) are included in the **[Getting Started Guide](docs/installation/GETTING-STARTED.md)**.

---

### Network Requirements

Your jumphost needs network access to:
- **Ops Manager** (port 443)
- **vCenter** (port 443) - if using vSphere
- **TAS API** (port 443) - for CF CLI
- **Internet** (for downloading tiles and stemcells) - or internal repository

### SSH Access

You need SSH access to Ops Manager or BOSH VMs for troubleshooting and maintenance.

**Windows users:** You can use:
- **OpenSSH for Windows** (built into Windows 10/11)
- **PuTTY** and PuTTYgen for key generation
- **Windows Subsystem for Linux (WSL)** for full Linux tooling

**Generate SSH key (OpenSSH for Windows or Linux):**

```bash
# Generate SSH key (if not already present)
ssh-keygen -t rsa -b 4096 -C "ops-manager-key"

# The public key will be added to Ops Manager during configuration
# Private key used for SSH connections
```

**Note:** The public key will be added to Ops Manager during Director configuration. Keep the private key secure.

---

## Quick Start

See full documentation in the README sections below.

### 1. Verify Prerequisites

```cmd
ops-scripts\verify-prerequisites.bat
```

### 2. Configure Environment Credentials

Copy and edit the environment credentials file with your Ops Manager details:

```cmd
copy env-creds\sandbox\om-env-redacted.yml env-creds\sandbox\om-env.yml
notepad env-creds\sandbox\om-env.yml
```

### 3. Backup Existing Configuration (if Ops Manager already configured)

```cmd
ops-scripts\backup-foundation-config.bat sandbox
```

### 4. Configure and Deploy

```cmd
REM Configure BOSH Director using backed-up config
ops-scripts\configure-director.bat sandbox config-backup\<backup-folder>\director-config.yml

REM Apply Director changes
ops-scripts\apply-changes.bat sandbox p-bosh

REM Configure TAS using backed-up config
ops-scripts\configure-product.bat sandbox cf config-backup\<backup-folder>\cf-config.yml

REM Apply TAS changes
ops-scripts\apply-changes.bat sandbox cf
```

**Note:** The scripts expect configuration files (typically extracted via backup). See the [Getting Started Guide](docs/installation/GETTING-STARTED.md) for complete workflow including initial setup.

