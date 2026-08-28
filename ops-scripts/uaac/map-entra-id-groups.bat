@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Map MS Entra ID (Azure AD) SAML group Object IDs to UAA/Cloud Controller scopes.
REM Pulls the UAA admin client credentials from Ops Manager itself (om credentials),
REM the same way create-cf-mgmt-uaa-client.bat does, so no admin secret has to be
REM typed in or stored by hand.
REM
REM This is what makes the saml_group: references in cf-mgmt's spaceConfig.yml files
REM (see cf-mgmt-config\production\...) actually resolve to something at the identity
REM layer -- cf-mgmt authorizes a group into a space's role, but UAA is what has to
REM already know that external group exists and map it to scopes.
REM
REM Group Object IDs come from env-creds\cf-groups.yml, not command-line arguments --
REM the same two groups are used across every foundation, so there's one file to
REM maintain instead of copy-pasted GUIDs in each invocation. See
REM env-creds\cf-groups-redacted.yml for the template.
REM
REM Usage: map-entra-id-groups.bat <foundation-name> <system-domain> [saml-origin-override]
REM Example: map-entra-id-groups.bat production sys.agi-explorer.com
REM Example: map-entra-id-groups.bat production sys.agi-explorer.com "azure-ad"

set FOUNDATION=%1
set SYSTEM_DOMAIN=%2
set SAML_ORIGIN_OVERRIDE=%3

if "%FOUNDATION%"=="" goto usage
if "%SYSTEM_DOMAIN%"=="" goto usage
goto args_ok

:usage
echo Usage: %0 ^<foundation-name^> ^<system-domain^> [saml-origin-override]
echo Example: %0 production sys.agi-explorer.com
echo Example: %0 production sys.agi-explorer.com "azure-ad"
echo.
echo Group Object IDs are NOT passed on the command line -- they're read from
echo env-creds\cf-groups.yml, which applies to every foundation. If that file
echo doesn't exist yet:
echo   copy env-creds\cf-groups-redacted.yml env-creds\cf-groups.yml
echo   notepad env-creds\cf-groups.yml
echo.
echo saml-origin-override   UAA identity provider origin name. Optional --
echo                        overrides saml_origin from cf-groups.yml if given.
echo                        Defaults to "saml" if set in neither place.
echo.
echo WARNING: admin_group_object_id in cf-groups.yml maps to cloud_controller.admin
echo -- full Cloud Controller / platform admin. Confirm that's really the intended
echo scope for that group before running this against a foundation.
exit /b 1

:args_ok

where jq >nul 2>&1
if errorlevel 1 (
    echo Error: jq is required ^(used to parse the credentials om returns^). See README.md.
    exit /b 1
)

where uaac >nul 2>&1
if errorlevel 1 (
    echo Error: uaac is required. See docs\installation\GETTING-STARTED.md Step 5.
    exit /b 1
)

REM === Read group Object IDs and default SAML origin from cf-groups.yml ===
REM Pure-batch parser -- one "key: value" pair per line, "#" full-line
REM comments, no nesting. Quotes around a value are NOT stripped -- they're
REM passed through as-is, which is what lets a value containing a space
REM (e.g. saml_origin: "Azure AD") survive as one argument once it reaches
REM the uaac calls below. Not a general YAML parser; see
REM env-creds\cf-groups-redacted.yml for the exact format this expects.
set CF_GROUPS_FILE=env-creds\cf-groups.yml

if not exist "%CF_GROUPS_FILE%" (
    echo Error: %CF_GROUPS_FILE% not found.
    echo This file holds the Entra ID group Object IDs used across every foundation.
    echo Create it from the template:
    echo   copy env-creds\cf-groups-redacted.yml env-creds\cf-groups.yml
    echo   notepad env-creds\cf-groups.yml
    exit /b 1
)

set "ADMIN_GROUP_ID="
set "DEVELOPER_GROUP_ID="
set "SAML_ORIGIN="

for /f "usebackq eol=# tokens=1* delims=: " %%a in ("%CF_GROUPS_FILE%") do (
    set "CFG_KEY=%%a"
    set "CFG_VAL=%%b"
    if defined CFG_VAL if "!CFG_VAL:~-1!"==" " set "CFG_VAL=!CFG_VAL:~0,-1!"
    if defined CFG_VAL if "!CFG_VAL:~-1!"==" " set "CFG_VAL=!CFG_VAL:~0,-1!"
    if defined CFG_VAL if "!CFG_VAL:~-1!"==" " set "CFG_VAL=!CFG_VAL:~0,-1!"
    if /i "!CFG_KEY!"=="admin_group_object_id" set "ADMIN_GROUP_ID=!CFG_VAL!"
    if /i "!CFG_KEY!"=="developer_group_object_id" set "DEVELOPER_GROUP_ID=!CFG_VAL!"
    if /i "!CFG_KEY!"=="saml_origin" set "SAML_ORIGIN=!CFG_VAL!"
)

if not "%SAML_ORIGIN_OVERRIDE%"=="" set SAML_ORIGIN=%SAML_ORIGIN_OVERRIDE%
if "%SAML_ORIGIN%"=="" set SAML_ORIGIN=saml

if "%ADMIN_GROUP_ID%"=="" (
    echo Error: admin_group_object_id is missing or empty in %CF_GROUPS_FILE%.
    exit /b 1
)
if "%DEVELOPER_GROUP_ID%"=="" (
    echo Error: developer_group_object_id is missing or empty in %CF_GROUPS_FILE%.
    exit /b 1
)

echo Read from %CF_GROUPS_FILE%:
echo   admin_group_object_id     = %ADMIN_GROUP_ID%
echo   developer_group_object_id = %DEVELOPER_GROUP_ID%
echo   saml_origin                = %SAML_ORIGIN%
echo.

echo === Fetching UAA admin client credentials from Ops Manager for foundation: %FOUNDATION% ===

REM credential-reference name for the cf tile's UAA admin client, per:
REM https://github.com/pivotal-cf/om/blob/main/docs/credentials/README.md
set CREDS_FILE=%TEMP%\uaa-admin-creds-%FOUNDATION%.json
call ops-scripts\om-command.bat %FOUNDATION% credentials -p cf -c .uaa.admin_client_credentials --format json > "%CREDS_FILE%"

if %ERRORLEVEL% NEQ 0 (
    echo === Failed to fetch UAA admin credentials from Ops Manager ===
    echo Run this to see the credential reference names actually available on this
    echo foundation, in case .uaa.admin_client_credentials is named differently here:
    echo   ops-scripts\om-command.bat %FOUNDATION% credentials -p cf
    del "%CREDS_FILE%" 2>nul
    exit /b 1
)

for /f "usebackq delims=" %%i in (`jq -r ".identity" "%CREDS_FILE%"`) do set ADMIN_CLIENT_ID=%%i
for /f "usebackq delims=" %%i in (`jq -r ".password" "%CREDS_FILE%"`) do set ADMIN_CLIENT_SECRET=%%i
del "%CREDS_FILE%" 2>nul

if "%ADMIN_CLIENT_ID%"=="" (
    echo Error: could not parse admin client identity from Ops Manager's response.
    exit /b 1
)
if "%ADMIN_CLIENT_SECRET%"=="" (
    echo Error: could not parse admin client secret from Ops Manager's response.
    exit /b 1
)

echo Admin UAA client: %ADMIN_CLIENT_ID%

echo === Targeting foundation UAA: https://uaa.%SYSTEM_DOMAIN% ===
uaac target https://uaa.%SYSTEM_DOMAIN%  --skip-ssl-validation
if %ERRORLEVEL% NEQ 0 (
    echo === Failed to target https://uaa.%SYSTEM_DOMAIN% ===
    exit /b 1
)

uaac token client get %ADMIN_CLIENT_ID% -s %ADMIN_CLIENT_SECRET%
if %ERRORLEVEL% NEQ 0 (
    echo === Failed to authenticate as %ADMIN_CLIENT_ID% ===
    exit /b 1
)

set FAILCOUNT=0

echo === Mapping admin group [%ADMIN_GROUP_ID%] to cloud_controller.admin ===
uaac group map --name cloud_controller.admin  %ADMIN_GROUP_ID% --origin %SAML_ORIGIN%
if %ERRORLEVEL% NEQ 0 (
    echo   FAILED: cloud_controller.admin mapping
    set /a FAILCOUNT+=1
) else (
    echo   OK
)

echo === Mapping developer group [%DEVELOPER_GROUP_ID%] to cloud_controller.read ===
uaac group map --name cloud_controller.read  %DEVELOPER_GROUP_ID% --origin %SAML_ORIGIN%
if %ERRORLEVEL% NEQ 0 (
    echo   FAILED: cloud_controller.read mapping
    set /a FAILCOUNT+=1
) else (
    echo   OK
)

echo === Mapping developer group [%DEVELOPER_GROUP_ID%] to cloud_controller.write ===
uaac group map --name cloud_controller.write  %DEVELOPER_GROUP_ID% --origin %SAML_ORIGIN%
if %ERRORLEVEL% NEQ 0 (
    echo   FAILED: cloud_controller.write mapping
    set /a FAILCOUNT+=1
) else (
    echo   OK
)

echo.
echo === Current group mappings for origin %SAML_ORIGIN% ===
uaac group map

if %FAILCOUNT% GTR 0 (
    echo.
    echo === %FAILCOUNT% mapping^(s^) FAILED -- see output above ===
    echo A common cause: %ADMIN_CLIENT_ID% doesn't itself hold the scope it's trying to
    echo hand out ^(uaac group map has the same "granting client needs the scope itself"
    echo restriction as uaac client update -- see CF-MGMT-INSTALLATION.md Troubleshooting^).
    exit /b 1
)

echo.
echo === All group mappings created/updated successfully ===
echo Next: put the same real group Object IDs from %CF_GROUPS_FILE% into the
echo saml_group: entries in cf-mgmt-config\production\*\spaceConfig.yml so cf-mgmt's
echo org/space role assignment actually resolves to these same groups.

endlocal
