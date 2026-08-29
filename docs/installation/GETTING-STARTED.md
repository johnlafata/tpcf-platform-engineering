# Getting Started - Quick Workflow

This guide provides a streamlined workflow for setting up and deploying a Tanzu foundation using platform automation.

## Overview

The process follows these steps:
0. **Deploy Ops Manager** (prerequisite)
1. **Setup jumphost** with required CLI tools
2. **Collect variables** for your environment
4. **Validate** configuration
5. **Deploy**

---

## Phase 0: Deploy Ops Manager (Prerequisite)

**Before starting this workflow, you must have Ops Manager deployed and running.**

### New Ops Manager Deployment

If you're deploying a new Tanzu foundation from scratch, you need to deploy Ops Manager first:

1. **Download Ops Manager OVA** from [Broadcom Support Portal](https://support.broadcom.com/)
   - Navigate to: VMware Tanzu → Tanzu Operations Manager
   - Download the appropriate version for your environment

2. **Deploy Ops Manager OVA to vSphere**

   Follow the official deployment guide:

   📖 **[Deploying Ops Manager on vSphere](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/tanzu-operations-manager/3-2/tanzu-ops-manager/vsphere-deploy.html)**

   Key deployment parameters you'll need:
   - vCenter datacenter, cluster, resource pool
   - Datastore for VM storage
   - Network configuration (IP, netmask, gateway, DNS)

3. **Start Ops Manager VM**

   After deploying the OVA:

   📖 **[Starting Tanzu Operations Manager](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/tanzu-operations-manager/3-3/tanzu-ops-manager/vsphere-deploy.html#start-tanzu-operations-manager)**

   ```bash
   # Power on the VM in vSphere
   # Navigate to: VM → Power → Power On

   # Wait 5-10 minutes for Ops Manager to start
   # Access the UI at: https://<opsmgr-ip>
   ```

4. **Complete Initial Setup**

   - Access Ops Manager UI: `https://<opsmgr-ip>`
   - Configure authentication (internal or LDAP/SAML)
   - Specify an Admin username and password
   - **Decryption passphrase** (⚠️ CRITICAL - store securely!)

5. **🔴 CRITICAL: Document These Credentials**

   Store in a secure password manager **immediately**:
   - [ ] **Decryption Passphrase** (cannot be recovered if lost!)
   - [ ] Admin username and password
   - [ ] Ops Manager URL/IP address
   - [ ] SSH private key associated with public key you uploaded during deployment.

   **Why this matters:** Without the decryption passphrase, you cannot restart or recover Ops Manager if the VM is powered off.

### Verification

Before proceeding, verify Ops Manager is accessible:

```bash
# Test connectivity
curl -k https://<opsmgr-ip>

# Should return HTML (Ops Manager login page)
```

Once Ops Manager is running and accessible, proceed to Phase 1.

---

## Phase 1: Jumphost Setup (One-time)

### Prerequisites

**Git** is required for managing configuration in source control and must be installed first.

### Windows Installation Guide

#### Step 1: Create Installation Directory

Create a directory for CLI tools and add it to your PATH:

```cmd
cd %LOCALAPPDATA%
mkdir Programs\platform-automation
set PATH=%PATH%;%LOCALAPPDATA%\Programs\platform-automation
```

> **Tip:** To make the PATH change permanent, add `%LOCALAPPDATA%\Programs\platform-automation` via **System Properties → Environment Variables**.

#### Step 2: Install Git (Required)

Git is a **prerequisite** for managing platform automation configurations.

1. Download Git for Windows: https://git-scm.com/download/win
2. Run the installer
3. Use default options (includes Git Bash)
4. Verify installation:
   ```cmd
   git --version
   ```

#### Step 3: Install Required CLI Tools

##### 1. OM CLI (Ops Manager automation)

1. Download from: https://github.com/pivotal-cf/om/releases
2. Get `om-windows-amd64-7.20.1.exe` (or latest version)
3. Rename to `om.exe`
4. Move `om.exe` to `%LOCALAPPDATA%\Programs\platform-automation`
5. Verify:
   ```powershell
   om version
   ```

##### 2. CF CLI (Cloud Foundry/TAS management)

1. Download Windows installer from: https://github.com/cloudfoundry/cli/releases
2. Run `cf8-cli-installer_*_x86-64.msi`
3. Follow the installation wizard
4. Verify:
   ```cmd
   cf version
   ```

##### 3. BOSH CLI (Optional - can be run on bosh director vm)

1. Download from: https://github.com/cloudfoundry/bosh-cli/releases
2. Get `bosh-cli-7.6.2-windows-amd64.exe` (or latest version)
3. Rename to `bosh.exe`
4. Move to `%LOCALAPPDATA%\Programs\platform-automation`
5. Verify:
   ```cmd
   bosh -v
   ```

Creating the cf-mgmt UAA client and mapping Entra ID groups to UAA scopes are currently done by hand, following the command references in `ops-scripts\uaac\create-cf-mgmt-uaac-user.md` and `ops-scripts\uaac\map-uaac-groups-admin-developer.md` -- see `docs\installation\CF-MGMT-INSTALLATION.md`.

#### Step 5: Install UAAC (for SAML/OIDC authentication)

UAAC is needed to create the client for the Ops Manager API when using SAML or OIDC authentication.

**UAAC requires Ruby:**

1. Download Ruby+Devkit from: https://rubyinstaller.org/downloads/
2. Get Ruby+Devkit 3.4.9.1 (x64) or latest version
3. Run the installer, choose the base install
4. Install UAAC:
   ```cmd
   gem install cf-uaac
   ```

**Configure UAAC for Ops Manager (if using SAML/OIDC):**

1. Target your Ops Manager UAA server:
   ```cmd
   uaac target https://OPS-MAN-FQDN/uaa  --skip-ssl-validation
   ```
   Example:
   ```cmd
   uaac target https://opsmgr-sbx.YOUR-DOMAIN/uaa  --skip-ssl-validation
   ```

2. Retrieve your UAA token:
   ```cmd
   uaac token sso get
   Client ID: opsman
   Client secret: [Leave Blank]
   Passcode: [Get from https://OPS-MAN-FQDN/uaa/passcode]
   ```

3. Create UAAC client for automation:
   ```cmd
   uaac client add om-automation --secret YOUR-SECRET --scope opsman.admin --authorized_grant_types client_credentials --authorities opsman.admin --access_token_validity 43200
   ```

4. Validate the client:
   ```cmd
   set OM_TARGET=opsmgr-sbx.YOUR-DOMAIN
   set OM_CLIENT_ID=om-automation
   set OM_CLIENT_SECRET=YOUR-SECRET
   om products
   ```

#### Step 6: Verify All Prerequisites

Run the verification script to check all installations:

```powershell
.\ops-scripts\verify-prerequisites.bat
```

### Mac/Linux Installation (Homebrew)

```bash
# Install Git (if not already installed)
brew install git

# Install platform automation tools
brew tap pivotal-cf/om https://github.com/pivotal-cf/om
brew install om
brew install cloudfoundry/tap/credhub-cli
brew install cloudfoundry/tap/bosh-cli
brew install cloudfoundry/tap/cf-cli@8
```




---

## Daily Operations
### Configuration Changes

### Tile Upgrades

**Windows:**
```batch
REM 1. Backup current config
ops-scripts\backup-foundation-config.bat sandbox

REM 2. Upload new tile
ops-scripts\upload-product.bat sandbox C:\path\to\cf-10.1.0.pivotal

REM 3. Stage new version
ops-scripts\stage-product.bat sandbox cf 10.1.0

REM 4. Re-apply configuration (uses existing vars)
ops-scripts\configure-product.bat sandbox cf

REM 5. Deploy
ops-scripts\apply-changes.bat sandbox cf
```

---

## Quick Reference

**Windows:**
```batch
REM Backup configuration
ops-scripts\backup-foundation-config.bat sandbox

REM Configure Director
ops-scripts\configure-director.bat sandbox director-config.yml

REM Upload and stage product
ops-scripts\upload-product.bat sandbox product.pivotal
ops-scripts\stage-product.bat sandbox cf 10.0.5

REM Configure product
ops-scripts\configure-product.bat sandbox cf

REM Apply changes
ops-scripts\apply-changes.bat sandbox
ops-scripts\apply-changes.bat sandbox cf
```

---

## Next Steps After Initial Deployment

### 1. Commit Configuration to Git

**Git commands are the same on all platforms:**

```bash
# Update the remote URL if needed
git remote set-url origin git@github.com:your-org/tpcf-platform-engineering.git

# Verify the remote
git remote -v

# Stage and commit changes
git add environments/ products/ ops-scripts/ .gitignore
git commit -m "Update foundation configuration"

# Push changes
git push origin main
```

