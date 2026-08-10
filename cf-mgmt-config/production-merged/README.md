# cf-mgmt Config — production-merged

Single, unified config for the production foundation: the real, live `system` org (copied verbatim from `production-save`, a genuine `export-config` snapshot) plus the new `internal`/`external` org design from `technical notes/TanzuCF_Configuration_Automation.docx`.

`production/` (internal/external only) and `production-save/` (system only, live export) are both left untouched — this folder is the new proposed single source of truth going forward, not a replacement of either.

## What's verbatim from the live export (`production-save`)

Unchanged, byte-for-byte:

- `system/` — orgConfig, spaces.yml (9 spaces), all per-space `spaceConfig.yml` / `security-group.json`
- `org_quotas/default.yml`, `org_quotas/runaway.yml`
- `spaceDefaults.yml`
- `ldap.yml` (disabled)
- `default_asgs/default_security_group.json`
- `asgs/credhub_open.json`, `asgs/db_open.json`
- `cf-mgmt.yml` — **except** one added line (see below)
- `orgs.yml` — **except** `internal`/`external` appended to the org list (see below)

## What's new (from the docx design)

- `internal/`, `external/` — orgConfig, spaces.yml, and all `spaceConfig.yml` for the `weeklybriefings`/`eHandbook`/`www` UI/API space pairs
- `asgs/sql-access-asg.json` — bound only to the three `-api` spaceConfigs
- `orgs.yml` — appended `internal` and `external` to the org list (kept `system`, `enable-delete-orgs: false`, and the existing `protected_orgs` list unchanged)
- `cf-mgmt.yml` — added one new entry under the existing `shared-domains` map for the new public vanity domain (`YOUR-DOMAIN` placeholder — see below); everything else in that file, including the real `service-access` list, is untouched

## Important finding: port 1433 is not actually blocked today, and adding a file won't fix that

The live `default_asgs/default_security_group.json` — already wired in as the platform's default running **and** staging security group via `cf-mgmt.yml`'s `running-security-groups:` / `staging-security-groups:` keys — currently allows **all protocols, all ports, to nearly every destination** (it only excludes the `169.254.0.0/16` link-local/metadata range). It does not restrict port 1433 today.

Cloud Foundry ASGs are allow-only — there is no "deny" rule, and multiple bound ASGs are additive. Because of that, simply adding a second, more restrictive default ASG (e.g. a `default-deny-1433.json`) alongside the existing permissive one would have **no effect**: every app would still get the union of both, which is still "allow everything." The only way to actually close off 1433 platform-wide is to edit `default_asgs/default_security_group.json` itself to explicitly exclude it.

**I have not made that edit.** It changes default network egress for every app on the platform (not just the new `internal`/`external` orgs), which is a much bigger blast radius than this task and needs an explicit decision from whoever owns that default. Let me know if you want me to draft the modified `default_security_group.json` (as a proposed diff, not applied) once you've confirmed the intended change.

## Placeholders to resolve before running `cf-mgmt apply`

| File | Placeholder | Needed from |
|---|---|---|
| `cf-mgmt.yml` | `YOUR-DOMAIN` (new line under `shared-domains`) | the top level domain  — **`enable-remove-shared-domains: true` is already set in this file**, so an unresolved placeholder here isn't just inert; applying it as-is would try to create a domain literally named `YOUR-DOMAIN` |
| `asgs/sql-access-asg.json` | `<ENTERPRISE-SQL-SERVER-IP>` | DBA/network team — production SQL server IP |
| every `internal/`/`external/*/spaceConfig.yml` | `entra-id-platform-users` | identity team — actual Entra ID group name + UAA scope mapping |
| — | port 1433 default-deny | see finding above — needs an explicit decision before any `default_security_group.json` edit |

## Before applying

This folder now governs the **entire** production foundation, not just the new orgs. Given `enable-delete-orgs: false` but `enable-remove-shared-domains: true` and `enable-delete-spaces: true` (set in `system/spaces.yml`) are both live in this config, treat any `cf-mgmt apply` against this folder as high-blast-radius:

```cmd
cf-mgmt apply --config-dir=cf-mgmt-config\production-merged --system-domain=SYSTEM-DOMAIN --user-id=cf-mgmt --client-secret=YOUR-SECRET --peek
```

Read the full `--peek` diff line by line — confirm it shows only the *additions* you expect (the new orgs/spaces/ASG) and nothing unexpected touching `system` — before ever dropping `--peek`.
