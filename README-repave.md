# Repaving a Foundation

Repaving means tearing down and rebuilding an **existing** foundation from scratch — for example after a corrupted BOSH Director, a botched configuration change, or a full environment rebuild. It assumes the foundation already has configuration on file (from a prior `backup-foundation-config.bat` run, and `cf-mgmt-config\<foundation>\` if cf-mgmt is in use for it). If you're standing up a brand-new foundation instead, use the [Getting Started Guide](docs/installation/GETTING-STARTED.md).

> Every command below that references a `-redacted` file is a template: copy it to its real name and edit in your actual API endpoint, credentials, and paths before running. Don't run the `-redacted` files directly, and don't commit the edited copies.

## 1. Back up the current installation

```cmd
ops-scripts\backup-foundation-config.bat sandbox
```

This writes the current Director and product configs to `config-backup\sandbox-<timestamp>\`. You'll need the paths it prints in steps 3 and 4.

## 2. Remove the old installation

```cmd
ops-scripts\om-command.bat sandbox delete-installation
```

## 3. Reconfigure the BOSH Director

Before reapplying, open the backed-up `director-config.yml` and remove any resource-group GUIDs — they're specific to the old installation and will fail validation against the fresh one.

```cmd
ops-scripts\configure-director.bat sandbox config-backup\sandbox-<timestamp>\director-config.yml
ops-scripts\apply-changes.bat sandbox p-bosh
```

## 4. Upload, stage, and configure the CF/TAS tile

```cmd
ops-scripts\upload-product.bat sandbox downloaded-products\srt-<version>.pivotal
ops-scripts\stage-product.bat sandbox cf <version>
ops-scripts\configure-product.bat sandbox cf config-backup\sandbox-<timestamp>\cf-config.yml
ops-scripts\apply-changes.bat sandbox cf
```

Repeat this pattern for any other tiles the foundation runs (resource segments, Hub, platform-services, etc.), using each tile's own backed-up config file.

## 5. Restore shared domains, service access, and feature flags

```cmd
copy foundation-setup-redacted.bat foundation-setup.bat
notepad foundation-setup.bat
```

Edit in the real API endpoint, admin credentials, and vanity domain, then run it:

```cmd
foundation-setup.bat
```

This is a thin wrapper around `cf enable-service-access`, `cf enable-feature-flag`, and `cf create-shared-domain` — see [`foundation-setup-redacted.bat`](foundation-setup-redacted.bat) for exactly what it does before running it.

## 6. Restore orgs, spaces, users, isolation segments, and ASGs

Redeploying wipes Cloud Controller's org/space database along with everything else, so this has to be rebuilt too. Which approach applies depends on whether this foundation already has cf-mgmt config on file:

**If `cf-mgmt-config\<foundation>\` already exists for this foundation** (the common case for a repave), re-apply the existing declarative config rather than recreating anything by hand — see [cf-mgmt Installation Notes](docs/installation/CF-MGMT-INSTALLATION.md) for the `cf-mgmt apply` steps. That doc is also the canonical **post-deployment configuration** reference for orgs, spaces, users, isolation segments, and ASGs going forward.

**If this foundation predates cf-mgmt, or you're rebuilding without it**, fall back to the manual script:

```cmd
copy create-orgs-spaces-redacted.bat create-orgs-spaces.bat
notepad create-orgs-spaces.bat
```

Edit in the real API endpoint, admin credentials, org/space names, and jenkins-sa password, then run it:

```cmd
create-orgs-spaces.bat
```

See [`create-orgs-spaces-redacted.bat`](create-orgs-spaces-redacted.bat) for the full list of orgs, spaces, role grants, and ASGs it creates.

## 7. Recreate the cf-mgmt UAA client and re-map Entra ID groups

A repave also wipes the CF/TAS deployment's UAA, so the `cf-mgmt` client and the Entra ID → scope group mappings need to be set up again from scratch. Neither is covered by cf-mgmt itself or by step 6:

- [`ops-scripts\uaac\create-cf-mgmt-uaac-user.md`](ops-scripts/uaac/create-cf-mgmt-uaac-user.md) — provision the `cf-mgmt` UAA client
- [`ops-scripts\uaac\map-uaac-groups-admin-developer.md`](ops-scripts/uaac/map-uaac-groups-admin-developer.md) — map Entra ID groups to `cloud_controller.*` scopes

See [README-uaa.md](README-uaa.md) for background on the three UAAs on a foundation and where to find admin credentials for each.

## 8. Stage and configure any other tiles

Repeat step 4's upload/stage/configure/apply pattern for anything else the foundation runs.

## Post-deployment configuration

Once the foundation is back up, [cf-mgmt Installation Notes](docs/installation/CF-MGMT-INSTALLATION.md) is the canonical reference for ongoing org/space/user/ASG management, and [README-uaa.md](README-uaa.md) covers UAA accounts and group memberships in more depth.
