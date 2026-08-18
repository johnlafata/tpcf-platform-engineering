# cf-mgmt Config — production

This folder implements the org/space/ASG design from **`technical notes/TanzuCF_Configuration_Automation.docx`** — it is a **new, proposed configuration**, not an export of what's currently on the foundation. The live foundation currently only has the `system` org (see `cf-mgmt-config/production-save`, a real `export-config` snapshot); `internal` and `external` do not exist yet.

## Layout

```
production/
├── ldap.yml                  # disabled — this setup authorizes via saml_group, not LDAP sync
├── cf-mgmt.yml               # shared domain + smb service access
├── orgs.yml                  # internal, external
├── default_asgs/
│   └── default-deny-1433.json    # platform-wide baseline — no port 1433 egress
├── asgs/
│   └── sql-access-asg.json       # named ASG — bound only to *-api spaces
├── internal/                 # weeklybriefings + eHandbook
│   ├── orgConfig.yml
│   ├── spaces.yml
│   ├── weeklybriefings-ui/spaceConfig.yml
│   ├── weeklybriefings-api/spaceConfig.yml   # named-security-groups: [SQL-ACCESS-ASG]
│   ├── eHandbook-ui/spaceConfig.yml
│   └── eHandbook-api/spaceConfig.yml         # named-security-groups: [SQL-ACCESS-ASG]
└── external/                 # www 
    ├── orgConfig.yml
    ├── spaces.yml
    ├── www-ui/spaceConfig.yml
    └── www-api/spaceConfig.yml               # named-security-groups: [SQL-ACCESS-ASG]
```

Each app is split into a `-ui` space and an `-api` space so `SQL-ACCESS-ASG` can be bound only to the backend/API space that actually needs database egress — see Section 5 of the docx for why.

This is the **production** foundation's copy: humans are authorized as `space-auditor` (read-only) via the `saml_group` field, while `jenkins-sa` keeps `space-developer` everywhere so the deploy pipeline still works. The **dev** foundation's copy of these same files would swap that to `space-developer` for the human group instead — see Section 2.3 of the docx.

## Placeholders to resolve before running `cf-mgmt apply`

| File | Placeholder | Needed from |
|---|---|---|
| `cf-mgmt.yml` | `YOUR-DOMAIN` | the top level 
| `cf-mgmt.yml` | `smb-broker` | confirm actual service broker name for `smb` |
| `asgs/sql-access-asg.json` | `<ENTERPRISE-SQL-SERVER-IP>` | DBA/network team — **production** SQL server IP specifically (differs from dev/sandbox) |
| every `spaceConfig.yml` | `entra-id-platform-users` | identity team — actual Entra ID group name, plus confirm its UAA scope mapping (`cloud_controller.read`) |
| `default_asgs/default-deny-1433.json` | — | adjust the example DNS/HTTP/HTTPS baseline to match whatever the platform team already treats as default egress; just keep port 1433 out of it |

Also confirm the exact cf-mgmt config key used to wire `default_asgs/` in as the platform's actual default running/staging security group for the cf-mgmt version installed — see the note in Section 2.3 of the docx.

**Do not run `cf-mgmt apply` against this folder until the table above is resolved** — `--peek` first, always (see `docs/installation/CF-MGMT-INSTALLATION.md`).
