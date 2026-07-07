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

   📖 **[Starting Tanzu Operations Manager](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/tanzu-operations-manager/3-2/tanzu-ops-manager/vsphere-deploy.html#start-tanzu-operations-manager)**

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

##### 4. jq (JSON processing - required by scripts)

1. Download from: https://jqlang.github.io/jq/download/
2. Get `jq-windows-amd64.exe`
3. Rename to `jq.exe`
4. Move to `%LOCALAPPDATA%\Programs\platform-automation`
5. Verify:
   ```cmd
   jq --version
   ```

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
   uaac target https://OPS-MAN-FQDN/uaa
   ```
   Example:
   ```cmd
   uaac target https://opsmgr-sbx.YOUR-DOMAIN/uaa
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
brew install jq
```

---

## Phase 2: Collect Variables

### Step 1: Fill Out the Checklist

Open `VARIABLES-CHECKLIST.md` and collect these details:

**Ops Manager:**
- [ ] Ops Manager URL/IP
- [ ] Admin username and password

**vCenter:**
- [ ] vCenter host, username, password
- [ ] Datacenter name
- [ ] Cluster name
- [ ] Resource pool name
- [ ] Datastore names

**Networks (3 required):**
- [ ] Infrastructure: name, port group, CIDR, gateway, DNS
- [ ] Apps: name, port group, CIDR, gateway, DNS
- [ ] Services: name, port group, CIDR, gateway, DNS

**TAS Domains:**
- [ ] System domain (e.g., `sys.sbx.example.com`)
- [ ] Apps domain (e.g., `apps.sbx.example.com`)

### Step 2: Update Vars Files

Edit the vars files with your collected values using your preferred text editor:

**Windows:**
```powershell
# Director variables
notepad environments\sandbox\director-vars.yml
# or use: code, notepad++, or any text editor

# CF variables
notepad environments\sandbox\cf-vars.yml
```

**Linux/Mac:**
```bash
# Director variables
vim environments/sandbox/director-vars.yml
# or use: nano, code, or any text editor

# CF variables
vim environments/sandbox/cf-vars.yml
```

**Update these sections:**
- vCenter Configuration
- Availability Zones
- Network Configuration
- system_domain
- apps_domain
- insecure_docker_registry (if applicable)

---

## Phase 3: Deploy

### Step 1: Backup Current State (if re-deploying)

**Windows:**
```batch
ops-scripts\backup-foundation-config.bat sandbox
```

### Step 2: Deploy BOSH Director

**Windows:**
```batch
REM Configure Director
ops-scripts\configure-director.bat sandbox config-backup\sandbox-TIMESTAMP\director-config.yml

REM Apply changes
ops-scripts\apply-changes.bat sandbox
```

**What this does:**
1. Read the director configuration file
2. Apply configuration to Ops Manager
3. Deploy the Director (takes 20-30 minutes)

### Step 3: Upload and Stage TAS Tile

Download TAS tile first, then upload:

**Windows:**
```batch
ops-scripts\upload-product.bat sandbox C:\path\to\cf-10.0.5.pivotal
ops-scripts\stage-product.bat sandbox cf 10.0.5
```

### Step 4: Configure SRT ( SMALL RUNTIME CF)

**Windows:**
```batch
ops-scripts\configure-product.bat sandbox cf
```

**What this does:**
1. Read products/cf/config.yml
2. Interpolate with environments/sandbox/cf-vars.yml
3. Apply configuration

### Step 5: Deploy TAS

**Windows:**
```batch
ops-scripts\apply-changes.bat sandbox cf
```

This deploys TAS (takes 45-60 minutes)

### Step 6: Verify Deployment

**CF CLI commands are the same on all platforms:**

```bash
# Target the API
cf api https://api.sys.sbx.example.com --skip-ssl-validation

# Login as admin (get credentials from Ops Manager)
cf login

# Create an org and space
cf create-org test-org
cf create-space -o test-org test-space
cf target -o test-org -s test-space

# Deploy a test app
cf push test-app
```

---

## Troubleshooting

### "Variable not found" errors

```
Error: could not render variables: variable 'vcenter_datacenter' not defined
```

**Fix:** Edit `environments/sandbox/director-vars.yml` and add the missing variable

### "Cannot connect to CredHub"

```
Error: connection refused
```

**Fix:**
1. Ensure BOSH Director is deployed
2. Re-run `.\ops-scripts\setup-credhub.bat sandbox`

### "Ops Manager connection failed"

```
Error: could not execute request
```

**Fix:**
1. Verify Ops Manager URL in `env-creds\sandbox\om-env.yml`
2. Check network connectivity: `curl -k https://OPSMGR-IP`
3. Verify credentials are correct

### Apply changes fails

```
Error: task failed
```

**Fix:**
1. Check Ops Manager UI for detailed error
2. Review BOSH logs: `bosh -e ENV -d DEPLOYMENT logs`
3. Check BOSH task output for specific errors

---

## Daily Operations

### Configuration Changes

**Windows:**
```batch
REM 1. Edit vars file
notepad environments\sandbox\cf-vars.yml

REM 2. Apply configuration
ops-scripts\configure-product.bat sandbox cf

REM 3. Deploy changes
ops-scripts\apply-changes.bat sandbox cf
```

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
git remote set-url origin git@github.com:your-org/tpcf-platform-automation-workshop.git

# Verify the remote
git remote -v

# Stage and commit changes
git add environments/ products/ ops-scripts/ .gitignore
git commit -m "Update foundation configuration"

# Push changes
git push origin main
```

### 2. Setting Up Additional Foundations

Once sandbox is working:

**Windows:**
```batch
REM Copy sandbox configuration
xcopy /E /I environments\sandbox environments\prod

REM Edit production values
notepad environments\prod\director-vars.yml
notepad environments\prod\cf-vars.yml

REM Create production credentials file
copy env-creds\sandbox\om-env.yml env-creds\prod\om-env.yml
notepad env-creds\prod\om-env.yml

REM Deploy production
ops-scripts\configure-director.bat prod director-config.yml
ops-scripts\apply-changes.bat prod
```

### 3. Documentation References

- `VARIABLES-CHECKLIST.md` - Complete variable collection guide
- `README.md` - Full documentation
- Tanzu documentation: https://techdocs.broadcom.com/tanzu

---

## Getting Help

- Review script error output carefully
- Check Ops Manager UI for detailed errors
- Review BOSH logs for deployment issues
- Consult Tanzu documentation: https://techdocs.broadcom.com/tanzu
