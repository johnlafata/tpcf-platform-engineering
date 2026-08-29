# cf-mgmt Installation Notes

This guide covers installing and bootstrapping **cf-mgmt** on the jumphost, alongside the existing OM CLI automation in this repository.

## Where cf-mgmt Fits

The rest of this repository (`ops-scripts\*.bat`) uses **OM CLI** to deploy and configure Ops Manager, BOSH Director, and the TAS tile itself — see [`docs/installation/GETTING-STARTED.md`](GETTING-STARTED.md). **cf-mgmt** picks up after that: once a foundation's TAS API is up and reachable, cf-mgmt declaratively manages the things that live *inside* that foundation — orgs, spaces, user/role authorization, isolation segments, and application security groups — from a set of YAML/JSON files instead of one-off `cf` CLI commands.

| Tool | Manages | Runs against |
|---|---|---|
| OM CLI | Ops Manager, BOSH Director, TAS tile | Ops Manager API |
| cf-mgmt | Orgs, spaces, users, quotas, ASGs | TAS Cloud Controller / UAA API |

## Prerequisites

- **CF CLI** — already a required tool for this repo; see the CF CLI install steps in [`GETTING-STARTED.md`](GETTING-STARTED.md). cf-mgmt does not replace it.
- **A deployed, reachable TAS foundation** (system domain resolvable, API reachable on 443).
- **UAAC** (`gem install cf-uaac`) — already covered in `GETTING-STARTED.md` for the Ops Manager UAA; the same `uaac` binary is reused here, just pointed at the foundation's UAA instead of Ops Manager's.
- Either a CF admin **username/password**, or a **UAA client** with sufficient scopes (see [Create a UAA Client](#create-a-uaa-client-for-cf-mgmt) below).

## Installing cf-mgmt

Follolw the instructions to install the Commercially Supported Releaser of cf-mgmt below, it exists of a single `cf-mgmt` (or `cf-mgmt.exe`) binary — install it into the same tools directory already used for `om`, `cf`, and `bosh` (`%LOCALAPPDATA%\Programs\platform-automation` on Windows) so it's on `PATH` alongside them.

###  Commercially Supported Release (Broadcom Support Portal)

1. Sign in to [support.broadcom.com](https://support.broadcom.com/)
2. Go to **My Downloads** and search for `cf-mgmt`
3. Select **cf-mgmt for VMware Tanzu Platform** and download the desired release
4. Windows: rename the downloaded binary to `cf-mgmt.exe` and move it into `%LOCALAPPDATA%\Programs\platform-automation`
5. Mac/Linux: rename to `cf-mgmt`, `chmod +x cf-mgmt`, and move it onto your `PATH` (e.g. `/usr/local/bin`)

### Verify

```cmd
cf-mgmt version
```

```bash
# Mac/Linux
cf-mgmt version
```

Consider adding a `cf-mgmt` check to `ops-scripts\verify-prerequisites.bat` alongside the existing OM CLI / CF CLI / git checks, so a missing install is caught the same way.

## Create a UAA Client for cf-mgmt

cf-mgmt authenticates against the **foundation's own UAA** (not the Ops Manager UAA used elsewhere in this repo). It can run either as an admin user (`--user-id` / `--password`) or as a UAA client (`--client-secret`) — a dedicated client is the better fit for unattended/pipeline use.

Create the client using the following `uaac` commands:  

```cmd
REM Fetch the tile's UAA admin client credentials from Ops Manager (or type them in by hand):
ops-scripts\om-command.bat FOUNDATION credentials -p cf -c .uaa.admin_client_credentials -f identity
ops-scripts\om-command.bat FOUNDATION credentials -p cf -c .uaa.admin_client_credentials -f password

REM Target the foundation's UAA (not Ops Manager's)
uaac target https://uaa.SYSTEM-DOMAIN  --skip-ssl-validation

REM Get a token as an existing admin to create the client
uaac token client get admin -s ADMIN-CLIENT-SECRET

REM Create a dedicated client for cf-mgmt
uaac client add cf-mgmt --secret YOUR-SECRET ^
  --authorized_grant_types client_credentials ^
  --authorities cloud_controller.admin,scim.read,scim.write,clients.read,clients.write,clients.secret,clients.admin,uaa.admin,routing.router_groups.read
```

Pick your own `cf-mgmt` client secret and save it somewhere durable, e.g. `env-creds\<foundation>\cf-mgmt-env.yml` (gitignored).

`om credentials -p cf -c .uaa.admin_client_credentials` is the credential reference for the tile's UAA admin client — if that reference doesn't exist on your foundation, run `om credentials -p cf` (no `-c` flag) to list the actual reference names available and adjust.

`routing.router_groups.read` is easy to miss — it's not covered by `cloud_controller.admin`, but export-config needs it at the very end of the run to list TCP router groups. Without it, everything else (orgs, spaces, ASGs, quotas, shared domains) exports fine and the run only fails on that last step — see [Troubleshooting](#getting-routing-groups-unauthorized) below if you hit this after already creating the client.

## TODO - validate entry group interaction with cf-mgmt - do we need it?
## Map Entra ID Groups to UAA Scopes. 

The `saml_group:` references in the `spaceConfig.yml` files under `cf-mgmt-config\production\` (e.g. `entra-id-platform-users`) only work if UAA already knows about that external Entra ID group and maps it to real scopes. That mapping is separate from — and a prerequisite for — cf-mgmt's own org/space role assignment: cf-mgmt authorizes a group into a space's role, but UAA is what has to recognize the group exists in the first place.

MAP your user community to your cf permissions using the command reference:

```cmd
uaac target https://uaa.SYSTEM-DOMAIN --skip-ssl-validation
uaac token client get admin -s ADMIN-CLIENT-SECRET

REM permissions to Administrators
uaac group map --name cloud_controller.admin "ADMIN-GROUP-OBJECT-ID" --origin "Azure AD"

REM permissions to Developers
uaac group map --name cloud_controller.read "DEVELOPER-GROUP-OBJECT-ID" --origin "Azure AD"
uaac group map --name cloud_controller.write "DEVELOPER-GROUP-OBJECT-ID" --origin "Azure AD"
```

The maps:

- admin group Object ID → `cloud_controller.admin` (Administrative users)
- developer group Object ID → both `cloud_controller.read` and `cloud_controller.write`

Both are Entra ID **group Object IDs** (GUIDs), not group display names — confirm with the identity team which attribute your SAML assertion actually sends, since some Entra ID SAML configurations send the display name instead.

## TODO - validate entry group interaction with cf-mgmt - do we need it?
Once mapped, put the same real group Object IDs into the `saml_group:` entries in `cf-mgmt-config\<FOUNDATION>\*\spaceConfig.yml` (currently placeholders — see that folder's `README.md`) so cf-mgmt's role assignment and UAA's scope mapping point at the same groups.

## Bootstrap the Config Directory

cf-mgmt reads/writes a config folder per foundation, the same way `environments\<foundation>\` already holds this repo's OM/TAS vars files. A parallel `cf-mgmt-config\<foundation>\` folder keeps the two in sync without mixing them. Each folder needs the same `ldap.yml` stub used above before `export-config` will run against it:

```cmd
mkdir cf-mgmt-config\sandbox
echo enabled: false > cf-mgmt-config\sandbox\ldap.yml

mkdir cf-mgmt-config\dev
echo enabled: false > cf-mgmt-config\dev\ldap.yml

mkdir cf-mgmt-config\production
echo enabled: false > cf-mgmt-config\production\ldap.yml
```


Validate it — `export-config` is read-only (it only reads the foundation's current state and writes files locally), so it's a safe way to confirm the client can authenticate and actually see the foundation, without touching anything. **cf-mgmt expects the config-dir to already contain a minimal `ldap.yml`** even when you're not using LDAP sync (this repo's setup authorizes users via `saml_group` references directly, per the org/space configuration guide) — create that stub first, or export-config fails with `Error reading file <config-dir>/ldap.yml: ... cannot find the file specified`:

```cmd
mkdir cf-mgmt-config\_client-check
echo enabled: false > cf-mgmt-config\_client-check\ldap.yml

cf-mgmt export-config ^
  --config-dir=cf-mgmt-config\_client-check ^
  --system-domain=SYSTEM-DOMAIN ^
  --user-id=cf-mgmt ^
  --client-secret=YOUR-SECRET
```

If the client works, this exits cleanly and populates `cf-mgmt-config\_client-check\` with `orgs.yml` and a folder per org — open `orgs.yml` and spot-check that it lists orgs you recognize on the foundation. Delete `cf-mgmt-config\_client-check\` afterward; the real export in [Bootstrap the Config Directory](#bootstrap-the-config-directory) below is what you'll actually keep.

> **Note:** confirm the exact authority list, and the exact `ldap.yml` schema for a disabled/no-LDAP setup, against the current cf-mgmt docs for the version installed — both have changed across releases:
> https://github.com/vmware-tanzu-labs/cf-mgmt/tree/main/docs


# Seed a foundation's cf-mgmt config, e.g. `cf-mgmt-config\sandbox` directly from the foundation's current state:

```cmd
cf-mgmt export-config ^
  --config-dir=cf-mgmt-config\sandbox ^
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

## Troubleshooting

### "Unable to initialize cf-mgmt" / "Error reading file ...ldap.yml"

```
E0803 09:19:11.955054 2444 export_config.go:21] Unable to initialize cf-mgmt. Error : Error reading file cf-mgmt-config\production/ldap.yml: open cf-mgmt-config\production/ldap.yml: The system cannot find the file specified.
```

**Cause:** cf-mgmt requires `ldap.yml` to already exist in `--config-dir` before `export-config` (or `apply`) will run, even if you don't use LDAP sync — it's not something either command creates for you.

**Fix:** create a minimal disabled stub in that config-dir, then re-run:

```cmd
echo enabled: false > cf-mgmt-config\production\ldap.yml
```

### "Getting routing groups: unauthorized"

```
E0803 09:36:33.781452 2808 export_config.go:54] Export failed with error:  Getting routing groups: unauthorized
error: Getting routing groups: unauthorized
```

**Cause:** this shows up at the very end of a run — orgs, spaces, named ASGs, quotas, and shared domains all export fine first, and only the last step (listing TCP router groups) fails. That's because `cloud_controller.admin` doesn't cover the Routing API; the client also needs `routing.router_groups.read`, which isn't in the authorities list further up in this doc until it's been added.

**Fix:** add the missing scope to the existing client and pull a fresh token before re-running (note it's `uaac client update`, not `client add`, since the client already exists):

```cmd
uaac target https://uaa.SYSTEM-DOMAIN  --skip-ssl-validation
uaac token client get admin -s ADMIN-CLIENT-SECRET

uaac client update cf-mgmt --authorities cloud_controller.admin,scim.read,scim.write,clients.read,clients.write,clients.secret,clients.admin,uaa.admin,routing.router_groups.read

REM cf-mgmt gets its own token via client_credentials at run time, so no separate
REM "uaac token client get cf-mgmt" step is needed — just re-run the export:
cf-mgmt export-config --system-domain sys.SYSTEM-DOMAIN --user-id cf-mgmt --client-secret YOUR-SECRET --config-dir=cf-mgmt-config\production
```

If it still fails after updating authorities, double check the client actually picked up the change:

```cmd
uaac client get cf-mgmt
```

and confirm `routing.router_groups.read` appears in the `authorities` list returned — **check the spelling carefully.** It's easy to type `routing.router-groups.read` (hyphen) instead of `routing.router_groups.read` (underscore between `router` and `groups`). UAA happily stores the hyphenated version as a valid-looking scope with no error, but it doesn't match anything the Routing API checks for, so the export still fails with the exact same "unauthorized" message — just as if the scope were never added at all. If `uaac client update` doesn't seem to be taking effect, this typo is the first thing to rule out before suspecting a client-permissions issue.

If the update genuinely isn't sticking (correct spelling, still missing after `uaac client get cf-mgmt`), that usually comes down to the *admin client's own* authorities — in UAA, a client generally can't grant a scope to another client unless it already holds that same scope itself, even with `uaa.admin`. Check `uaac client get admin` for `routing.router_groups.read` in its own authorities list; if it's missing there too, you'll need a client that already has it (often an internal platform client used by the router/routing-api components) or have whoever manages UAA add it directly.

## References

- cf-mgmt repo: https://github.com/vmware-tanzu-labs/cf-mgmt
- cf-mgmt docs: https://github.com/vmware-tanzu-labs/cf-mgmt/tree/main/docs
- Broadcom Support Portal: https://support.broadcom.com/
