# UAA Accounts & Group Memberships

This repo talks to **two separate UAA installations**, each with its own accounts, clients, and group mappings. They don't share data — a query against one tells you nothing about the other. This doc summarizes what lives where, how to check what's currently configured, and how the two `ops-scripts` UAA scripts in this repo fit in.

## The two UAAs

| | Ops Manager Director's UAA | CF/TAS Deployment's UAA |
|---|---|---|
| **Target URL** | `https://OPS-MAN-FQDN/uaa` | `https://uaa.SYSTEM-DOMAIN` |
| **What it controls** | Who can log into Ops Manager, install/configure tiles, run `om` commands | Who can `cf login`, use Apps Manager, push apps, manage orgs/spaces |
| **Key scopes/clients** | `opsman.admin` (e.g. the `om-automation` client from `GETTING-STARTED.md` Step 5) | `cloud_controller.admin` / `.read` / `.write`, the `cf-mgmt` client |
| **Admin credentials come from** | The Ops Manager admin user/password set during initial setup, or an `opsman.admin`-scoped client | The TAS tile's UAA admin client, fetched via `om credentials -p cf -c .uaa.admin_client_credentials` |
| **SAML/Entra config (if used)** | Configured separately under Ops Manager's own Settings > Authentication (see `TAS_Setup_Reference` Appendix B) | Configured under the TAS tile's Authentication and Enterprise SSO settings (see `TAS_Setup_Reference` Appendix A / A-1) |

If a `uaac` command isn't finding an account, client, or group mapping you expect, the first thing to check is whether you're targeted at the right one of these two.

## Investigating what's set up now

Run the same read-only `uaac` commands against each UAA in turn — re-target and re-authenticate between them, since a token from one won't work against the other.

**Ops Manager Director's UAA:**

```cmd
uaac target https://OPS-MAN-FQDN/uaa --skip-ssl-validation
uaac token sso get
REM Client ID: opsman, Client secret: [blank], Passcode: from https://OPS-MAN-FQDN/uaa/passcode
REM -- or, for a client-credentials automation client instead of an interactive login:
uaac token client get om-automation -s YOUR-SECRET

uaac users --attributes userName,origin,groups.display
uaac clients
```

**CF/TAS deployment's UAA:**

```cmd
uaac target https://uaa.SYSTEM-DOMAIN --skip-ssl-validation
uaac token client get admin -s ADMIN-CLIENT-SECRET

uaac users --attributes userName,origin,groups.display
```

Useful follow-ups once you're targeted at the CF deployment's UAA:

- **Who currently has a given scope** (most direct way to answer "who has admin"):
  ```cmd
  uaac group get cloud_controller.admin
  ```
- **All current external (SAML) group → scope mappings**, i.e. the live result of what `TAS_Setup_Reference` Appendix A-1 section 3 sets up:
  ```cmd
  uaac group map
  ```
- **Everything one specific user has:**
  ```cmd
  uaac user get USERNAME -a groups
  ```
- **Isolate SSO-linked accounts from internal ones** — swap in your actual SAML origin name (this repo's `TAS_Setup_Reference` example uses `"Azure AD"`; the `map-entra-id-groups.bat` script below defaults to `saml`):
  ```cmd
  uaac users --attributes userName,groups.display -q "origin eq \"saml\""
  ```

Note that UAA-level scopes (`cloud_controller.admin`, etc.) are a different layer from CF-level org/space roles. A user can hold `cloud_controller.admin` and still show up with no orgs in `cf orgs` — that's expected; see the "Admin Privileges with cloud_controller.admin" note in `TAS_Setup_Reference` Appendix A-1. For the CF-level role layer, use `cf org-users` / `cf space-users`, or `cf-mgmt export-config` for a full point-in-time YAML snapshot (see `docs\installation\CF-MGMT-INSTALLATION.md`).

## Setting things up: the two scripts in this repo

Both scripts authenticate to Ops Manager the same way `ops-scripts\om-command.bat` does, then fetch the TAS tile's UAA admin client via `om credentials -p cf -c .uaa.admin_client_credentials` — so no admin secret has to be typed in or stored by hand. Both target the **CF/TAS deployment's UAA** (`https://uaa.SYSTEM-DOMAIN`), not Ops Manager's.

### `create-cf-mgmt-uaa-client.bat` — provision the cf-mgmt client

Creates (or updates) the `cf-mgmt` UAA client with the authorities cf-mgmt needs (`cloud_controller.admin`, `scim.read`/`write`, `clients.*`, `uaa.admin`, `routing.router_groups.read`), and saves the result to `env-creds\<foundation>\cf-mgmt-env.yml` (gitignored):

```cmd
ops-scripts\create-cf-mgmt-uaa-client.bat production sys.SYSTEM-DOMAIN
```

Full detail, including the manual `uaac` equivalent and the `routing.router_groups.read` troubleshooting gotcha, is in `docs\installation\CF-MGMT-INSTALLATION.md`.

### `map-entra-id-groups.bat` — map Entra ID groups to UAA scopes

Maps an admin Entra ID group's Object ID to `cloud_controller.admin`, and a developer group's Object ID to both `cloud_controller.read` and `cloud_controller.write`:

```cmd
ops-scripts\map-entra-id-groups.bat production sys.SYSTEM-DOMAIN <ADMIN-GROUP-OBJECT-ID> <DEVELOPER-GROUP-OBJECT-ID>
```

Defaults to SAML origin `saml` — pass a fifth argument if your Entra integration uses a different origin name (the `TAS_Setup_Reference` doc's own worked example uses `"Azure AD"`):

```cmd
ops-scripts\map-entra-id-groups.bat production sys.SYSTEM-DOMAIN <ADMIN-GROUP-OBJECT-ID> <DEVELOPER-GROUP-OBJECT-ID> "Azure AD"
```

This is what makes the `saml_group:` entries in `cf-mgmt-config\production\*\spaceConfig.yml` actually resolve to real users — cf-mgmt authorizes a mapped group into a space's role, but UAA is what has to know the external group exists in the first place. Run `uaac group map` (above) afterward to confirm the mapping landed. Full detail is in `docs\installation\CF-MGMT-INSTALLATION.md`.

## References

- `docs\installation\GETTING-STARTED.md` — UAAC install (Step 5) and the Ops Manager UAA `om-automation` client
- `docs\installation\CF-MGMT-INSTALLATION.md` — full cf-mgmt install/bootstrap, both scripts in detail, troubleshooting
- `technical notes\TAS_Setup_Reference_2026-07-22.docx` — Appendix A-1 (Entra ID group mapping), Appendix B / B-2 (Ops Manager SAML + OM CLI), Appendix D (cleaning up duplicate identity providers)
- cf-mgmt repo: https://github.com/vmware-tanzu-labs/cf-mgmt
