# DEPLOYING TANZU ELASTIC APPLICATION RUNTIME (akaTAS, TPCF)

## Phase 2: Deploy

### Step 1: Backup Current State (if re-deploying)

**Windows:**
```batch
ops-scripts\backup-foundation-config.bat sandbox
```

### Step 2: Redeploy BOSH Director

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
