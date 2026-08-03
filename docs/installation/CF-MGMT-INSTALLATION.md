# cf-mgmt Installation Notes

This guide covers installing and bootstrapping **cf-mgmt** on the jumphost, alongside the existing OM CLI automation in this repository.

## Where cf-mgmt Fits

The rest of this repository (`ops-scripts\*.bat`) uses **OM CLI** to deploy and configure Ops Manager, BOSH Director, and the TAS tile itself — see [`docs/installation/GETTING-STARTED.md`](GETTING-STARTED.md). **cf-mgmt** picks up after that: once a foundation's TAS API is up and reachable, cf-mgmt declaratively manages the things that live *inside* that foundation — orgs, spaces, user/role authorization, isolation segments, and application security groups — from a set of YAML/JSON files instead of one-off `cf` CLI commands.

| Tool | Manages | Runs against |
|---|---|---|
| OM CLI | Ops Manager, BOSH Director, TAS tile | Ops Manager API |
| cf-mgmt | Orgs, spaces, users, quotas, ASGs | TAS Cloud Controller / UAA API |

## Prerequisites

- **CF CLI** — already a required tool for this repo; see the CF CLI install steps in [`GETTING-STARTED.md`](GETTING-STARTED.md#2-cf-cli-cloud-foundryctas-management). cf-mgmt does not replace it.
- **A deployed, reachable TAS foundation** (system domain resolvable, API reachable on 443).
- **UAAC** (`gem install cf-uaac`) — already covered in `GETTING-STARTED.md` for the Ops Manager UAA; the same `uaac` binary is reused here, just pointed at the foundation's UAA instead of Ops Manager's.
- Either a CF admin **username/password**, or a **UAA client** with sufficient scopes (see [Create a UAA Client](#create-a-uaa-client-for-cf-mgmt) below).

## Installing cf-mgmt

Pick one of the two release channels below. Both produce a single `cf-mgmt` (or `cf-mgmt.exe`) binary — install it into the same tools directory already used for `om`, `cf`, `bosh`, and `jq` (`%LOCALAPPDATA%\Programs\platform-automation` on Windows) so it's on `PATH` alongside them.

### Option A — Commercially Supported Release (Broadcom Support Portal)

1. Sign in to [support.broadcom.com](https://support.broadcom.com/)
2. Go to **My Downloads** and search for `cf-mgmt`
3. Select **cf-mgmt for VMware Tanzu Platform** and download the desired release
4. Windows: rename the downloaded binary to `cf-mgmt.exe` and move it into `%LOCALAPPDATA%\Programs\platform-automation`
5. Mac/Linux: rename to `cf-mgmt`, `chmod +x cf-mgmt`, and move it onto your `PATH` (e.g. `/usr/local/bin`)

### Option B — Latest Open Source Release (GitHub)

Official repo: https://github.com/vmware-tanzu-labs/cf-mgmt

1. Go to the [Releases page](https://github.com/vmware-tanzu-labs/cf-mgmt/releases)
2. Download the asset matching your OS/arch:
   - Windows: `cf-mgmt.exe` (or `cf-mgmt-config.exe` if you only need the config-scaffolding subcommand)
   - Mac: `cf-mgmt-osx` / `cf-mgmt-osx-arm64`
   - Linux: `cf-mgmt-linux` / `cf-mgmt-linux-arm64`
3. Windows: rename to `cf-mgmt.exe`, move into `%LOCALAPPDATA%\Programs\platform-automation`
4. Mac/Linux: rename to `cf-mgmt`, `chmod +x cf-mgmt`, move onto `PATH`

### Verify

```cmd
cf-mgmt version
```

```bash
# Mac/Linux
cf-mgmt version
```

Consider adding a `cf-mgmt` check to `ops-scripts\verify-prerequisites.bat` alongside the existing OM CLI / CF CLI / jq / git checks, so a missing install is caught the same way.

## Create a UAA Client for cf-mgmt

cf-mgmt authenticates against the **foundation's own UAA** (not the Ops Manager UAA used elsewhere in this repo). It can run either as an admin user (`--user-id` / `--password`) or as a UAA client (`--client-secret`) — a dedicated client is the better fit for unattended/pipeline use:

```cmd
REM Target the foundation's UAA (not Ops Manager's)
uaac target https://uaa.SYSTEM-DOMAIN

REM Get a token as an existing admin to create the client
uaac token client get admin -s ADMIN-CLIENT-SECRET

REM Create a dedicated client for cf-mgmt
uaac client add cf-mgmt --secret YOUR-SECRET ^
  --authorized_grant_types client_credentials ^
  --authorities cloud_controller.admin,scim.read,scim.write,clients.read,clients.write,clients.secret,clients.admin,uaa.admin
```

Validate it:

```cmd
cf-mgmt org-report --system-domain SYSTEM-DOMAIN --user-id cf-mgmt --client-secret YOUR-SECRET
```

> **Note:** confirm the exact authority list against the current cf-mgmt Getting Started docs for the version installed — required scopes have changed across releases:
> https://github.com/vmware-tanzu-labs/cf-mgmt/tree/main/docs

## Bootstrap the Config Directory

cf-mgmt reads/writes a config folder per foundation, the same way `environments\<foundation>\` already holds this repo's OM/TAS vars files. A parallel `cf-mgmt-config\<foundation>\` folder keeps the two in sync without mixing them:

```cmd
mkdir cf-mgmt-config\sandbox
mkdir cf-mgmt-config\production
```

Seed each from the foundation's current state, writing into the same `config-backup\` folder already used by `ops-scripts\backup-foundation-config.bat`, so all foundation backups — OM/TAS and cf-mgmt — live side by side:

```cmd
cf-mgmt export-config ^
  --config-dir=config-backup\sandbox-cf-mgmt-%DATE:~-4%%DATE:~4,2%%DATE:~7,2% ^
  --system-domain=SYSTEM-DOMAIN ^
  --user-id=cf-mgmt ^
  --client-secret=YOUR-SECRET
```

See the org/space/ASG configuration guide for how these files are structured and maintained going forward.

## Smoke Test

Before wiring cf-mgmt into any automation, do a dry run against the config folder you just exported:

```cmd
cf-mgmt apply ^
  --config-dir=cf-mgmt-config\sandbox ^
  --system-domain=SYSTEM-DOMAIN ^
  --user-id=cf-mgmt ^
  --client-secret=YOUR-SECRET ^
  --peek
```

`--peek` prints the changes cf-mgmt would make without applying them — confirm the diff is empty (or expected) before dropping the flag.

## References

- cf-mgmt repo: https://github.com/vmware-tanzu-labs/cf-mgmt
- cf-mgmt docs: https://github.com/vmware-tanzu-labs/cf-mgmt/tree/main/docs
- Broadcom Support Portal: https://support.broadcom.com/
