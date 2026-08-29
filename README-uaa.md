# UAA Accounts & Group Memberships

A TAS foundation runs **three separate UAA installations**, each with its own accounts, clients, scopes, and group mappings. They don't share data — a query against one tells you nothing about the others, and a token issued by one is rejected by the others. This doc summarizes what lives where, where to find the admin credentials that let you list users and inspect group mappings, and how the two `ops-scripts` UAA scripts in this repo fit in.

> Three is the baseline, not a ceiling. Tiles like TKGI, Concourse, and Healthwatch ship their own UAAs on top of these.

## The three UAAs

| | Ops Manager's UAA | BOSH Director's UAA | CF/TAS Deployment's UAA |
|---|---|---|---|
| **Target URL** | `https://OPS-MAN-FQDN/uaa` | `https://DIRECTOR-IP:8443` | `https://uaa.SYSTEM-DOMAIN` |
| **Runs on** | The Ops Manager VM | The BOSH Director VM (deployed *by* Ops Manager) | The `cf` deployment |
| **What it controls** | Who can log into Ops Manager, install/configure tiles, run `om` commands | Who can run `bosh` CLI commands against the Director | Who can `cf login`, use Apps Manager, push apps, manage orgs/spaces |
| **Key scopes** | `opsman.admin`, `opsman.user` | `bosh.admin` | `cloud_controller.admin` / `.read` / `.write` |
| **Known clients** | `opsman`, `om-automation` | `login`, `bosh_admin_client`, any CI client you add | `cf`, `admin`, `cf-mgmt` |
| **External auth (SAML/LDAP)** | Supported — this is the SAML/Entra-backed one for platform operators | **Not supported** — always internal auth | Supported — Entra ID groups map to `cloud_controller.*` scopes |
| **SAML/Entra config location** | Ops Manager Settings > Authentication (see `TAS_Setup_Reference` Appendix B) | n/a | TAS tile > Authentication and Enterprise SSO (see `TAS_Setup_Reference` Appendix A / A-1) |

If a `uaac` command isn't finding an account, client, or group mapping you expect, the first thing to check is which of these three you're actually targeted at (`uaac target` with no argument prints the current one).

## Where to find admin credentials

### Ops Manager's UAA

**If Ops Manager uses SAML/OIDC SSO** (as this foundation does), there is no admin password to look up — authenticate through the SSO passcode flow instead. The resulting token carries `uaa.admin` and `clients.admin`, which is sufficient for every read-only investigation command below:

```cmd
uaac target https://OPS-MAN-FQDN/uaa --skip-ssl-validation
uaac token sso get opsman -s ""
REM Prompts for a passcode -- open https://OPS-MAN-FQDN/uaa/passcode in a browser,
REM authenticate through Entra ID, and paste the passcode back at the prompt.
```

Confirm what you got with `uaac context` — look for `uaa.admin` in the `scope:` line.

**If Ops Manager uses internal auth**, use the owner/password grant with the Ops Manager admin account set during initial setup:

```cmd
uaac token owner get opsman -s ""
REM User name: admin, Password: <ops-manager-admin-password>
```

The `om-automation` client (`GETTING-STARTED.md` Step 5) is **not** usable for this — it holds `opsman.admin` only, with no `scim.*` authority, so `uaac users` returns an insufficient scope error.

### BOSH Director's UAA

Credentials live in the BOSH Director tile — product slug **`p-bosh`**, not `director`. Confirm the slug on your foundation with `ops-scripts\om-command.bat <foundation> products`, then list and fetch:

```cmd
ops-scripts\om-command.bat <foundation> credential-references -p p-bosh
ops-scripts\om-command.bat <foundation> credentials -p p-bosh -c .uaa_login_client_credentials
ops-scripts\om-command.bat <foundation> credentials -p p-bosh -c .uaa_admin_user_credentials
```

Note `om credentials` always requires `-c`; `om credential-references` is the separate command that lists what's available. The same values appear in the Ops Manager UI under BOSH Director tile > Credentials as **Uaa Login Client Credentials** and **Uaa Admin User Credentials**.

```cmd
uaac target https://DIRECTOR-IP:8443 --ca-cert /var/tempest/workspaces/default/root_ca_certificate
uaac token owner get login -s <UAA-LOGIN-CLIENT-PASSWORD>
REM User name: admin, Password: <UAA-ADMIN-USER-PASSWORD>
```

The Director IP is on the BOSH Director tile's Status tab. `bosh_admin_client` (**Uaa Bosh Client Credentials**, created when you tick "Provision an admin client in the Bosh UAA" during SAML/LDAP setup) holds `bosh.admin` only — fine for the `bosh` CLI, not sufficient for `uaac users`.

### CF/TAS Deployment's UAA

Fetch the TAS tile's UAA admin client — the same credential used in the manual steps below, so nothing has to be typed in or stored by hand:

```cmd
ops-scripts\om-command.bat <foundation> credentials -p cf -c .uaa.admin_client_credentials
```

```cmd
uaac target https://uaa.SYSTEM-DOMAIN --skip-ssl-validation
uaac token client get admin -s <ADMIN-CLIENT-SECRET>
```

The `cf-mgmt` client also works here and carries `scim.read`, `scim.write`, and `uaa.admin` — created by hand following `ops-scripts\uaac\create-cf-mgmt-uaac-user.md`. Save the secret you choose somewhere durable, e.g. `env-creds\<foundation>\cf-mgmt-env.yml` (gitignored), matching the format `cf-mgmt-config` docs expect. Treat it as an admin credential: `uaa.admin` lets it create and modify clients and scopes, not just read.

## Investigating what's set up now

Re-target and re-authenticate between UAAs — a token from one won't work against another.

**Listing users and their groups** works identically against all three, once authenticated with a token holding `scim.read` or `uaa.admin`:

```cmd
uaac users --attributes userName,origin,groups.display
uaac clients
uaac client get <CLIENT-ID>
```

`uaac client get <CLIENT-ID>` is the fastest way to answer "why did that token get insufficient scope" — it prints the client's actual authorities, which may have been narrowed since initial setup.

### Group mappings

External group → scope mapping only applies to the two UAAs that support external auth:

**CF/TAS deployment's UAA** — Entra ID groups are mapped to `cloud_controller.*` scopes with `uaac group map`, which is what `TAS_Setup_Reference` Appendix A-1 section 3 and `ops-scripts\uaac\map-uaac-groups-admin-developer.md` set up. Inspect the live result with:

```cmd
uaac group map
uaac group get cloud_controller.admin
uaac user get USERNAME -a groups
```

Isolate SSO-linked accounts from internal ones — swap in your actual SAML origin name (this repo's `TAS_Setup_Reference` example, and `ops-scripts\uaac\map-uaac-groups-admin-developer.md`, both use `"Azure AD"`):

```cmd
uaac users --attributes userName,groups.display -q "origin eq \"saml\""
```

**Ops Manager's UAA** — operator access is granted through the SAML group attribute and admin group name configured in Ops Manager's own Authentication settings (Appendix B), not by running `uaac group map` by hand. `uaac group map` and `uaac group get opsman.admin` still work for *inspecting* what's in effect.

**BOSH Director's UAA** — no external groups; users and clients are internal only, managed with `uaac user add` / `uaac client add` (see `TAS_Setup_Reference` on creating a `bosh.admin` CI client).

### UAA scopes vs CF org/space roles

UAA-level scopes (`cloud_controller.admin`, etc.) are a different layer from CF-level org/space roles. A user can hold `cloud_controller.admin` and still show no orgs in `cf orgs` — that's expected; see the "Admin Privileges with cloud_controller.admin" note in `TAS_Setup_Reference` Appendix A-1. For the CF-level role layer, use `cf org-users` / `cf space-users`, or `cf-mgmt export-config` for a full point-in-time YAML snapshot (see `docs\installation\CF-MGMT-INSTALLATION.md`).

## Setting things up: manual uaac steps

### `ops-scripts\uaac\create-cf-mgmt-uaac-user.md` — provision the cf-mgmt client

Creates the `cf-mgmt` UAA client with the authorities cf-mgmt needs (`cloud_controller.admin`, `scim.read`/`write`, `clients.*`, `uaa.admin`, `routing.router_groups.read`). Open the file and run each line by hand, substituting your system domain and admin client secret; pick your own `cf-mgmt` client secret and save it somewhere durable (e.g. `env-creds\<foundation>\cf-mgmt-env.yml`, gitignored).

Full detail, including the `routing.router_groups.read` troubleshooting gotcha, is in `docs\installation\CF-MGMT-INSTALLATION.md`.

### `ops-scripts\uaac\map-uaac-groups-admin-developer.md` — map Entra ID groups to UAA scopes

Maps an admin Entra ID group's Object ID to `cloud_controller.admin`, and a developer group's Object ID to both `cloud_controller.read` and `cloud_controller.write`. The Object IDs and `--origin "Azure AD"` are written directly into the file — edit the GUIDs in the file itself if they change for a given foundation. (`env-creds\cf-groups.yml` is no longer used for this.)

This is what makes the `saml_group:` entries in `cf-mgmt-config\production\*\spaceConfig.yml` actually resolve to real users — cf-mgmt authorizes a mapped group into a space's role, but UAA is what has to know the external group exists in the first place. Run `uaac group map` (above) afterward to confirm the mapping landed. Full detail is in `docs\installation\CF-MGMT-INSTALLATION.md`.

## References

- `docs\installation\GETTING-STARTED.md` — UAAC install (Step 5) and the Ops Manager UAA `om-automation` client
- `docs\installation\CF-MGMT-INSTALLATION.md` — full cf-mgmt install/bootstrap, both scripts in detail, troubleshooting
- `technical notes\TAS_Setup_Reference_2026-07-22.docx` — Appendix A-1 (Entra ID group mapping), Appendix B / B-2 (Ops Manager SAML + OM CLI), Appendix D (cleaning up duplicate identity providers)
- cf-mgmt repo: https://github.com/vmware-tanzu-labs/cf-mgmt
- om CLI commands: https://github.com/pivotal-cf/om/blob/main/docs/README.md#commands


## debugging federated metadata xml

 curl -o federationmetadata.xml "https://login.microsoftonline.com/224b9784-a475-4be4-af82-01ae85c097b8/federationmetadata/2007-06/federationmetadata.xml?appid=942f0bf2-a6da-4381-9894-f7e8ebeb9346"

 open the file federationmetadata.xml in vscode,
 click on the encoding at the bottom, 
 save with encoding, but choose only utf-8 (not utf-8 with BOM)