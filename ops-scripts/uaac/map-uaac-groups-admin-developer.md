# Map Entra ID Groups to UAA Scopes

Manual `uaac` command reference for mapping Entra ID (Azure AD) SAML group Object IDs to UAA/Cloud Controller scopes. 

The Object IDs and `--origin "Azure AD"` below  are written directly into this file — edit them here if they change for a given foundation or product. Tanzu Hub required --origin "azure-ad" instead of "Azure AD".

See [`docs/installation/CF-MGMT-INSTALLATION.md`](../../docs/installation/CF-MGMT-INSTALLATION.md) for full context.

```cmd
uaac target https://uaa.<sys-domain> --skip-ssl-validation

uaac token client get admin -s ADMIN-CLIENT-SECRET

REM permissions to Administrators
uaac group map --name cloud_controller.admin "074ca041-070f-4842-bf06-cdcf2161d9c7" --origin "Azure AD"

REM permissions to Developers
uaac group map --name cloud_controller.read "66805d4e-7fc0-4dfd-a32b-8fed56ee8574" --origin "Azure AD"
uaac group map --name cloud_controller.write "66805d4e-7fc0-4dfd-a32b-8fed56ee8574" --origin "Azure AD"
```
Both IDs are Entra ID **group Object IDs** (GUIDs), not group display names — confirm with the identity team which attribute your SAML assertion actually sends.
