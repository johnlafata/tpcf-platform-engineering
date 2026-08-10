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
REM Usage: map-entra-id-groups.bat <foundation-name> <system-domain> <admin-group-object-id> <developer-group-object-id> [saml-origin]
REM Example: map-entra-id-groups.bat production sys.agi-explorer.com <ADMIN-GROUP-OBJECT-ID> <DEVELOPER-GROUP-OBJECT-ID>
REM Example: map-entra-id-groups.bat production sys.agi-explorer.com 11111111-1111-1111-1111-111111111111 22222222-2222-2222-2222-222222222222 saml

set FOUNDATION=%1
set SYSTEM_DOMAIN=%2
set ADMIN_GROUP_ID=%3
set DEVELOPER_GROUP_ID=%4
set SAML_ORIGIN=%5

if "%SAML_ORIGIN%"=="" set SAML_ORIGIN=saml

if "%FOUNDATION%"=="" goto usage
if "%SYSTEM_DOMAIN%"=="" goto usage
if "%ADMIN_GROUP_ID%"=="" goto usage
if "%DEVELOPER_GROUP_ID%"=="" goto usage
goto args_ok

:usage
echo Usage: %0 ^<foundation-name^> ^<system-domain^> ^<admin-group-object-id^> ^<developer-group-object-id^> [saml-origin]
echo Example: %0 production sys.agi-explorer.com ^<ADMIN-GROUP-OBJECT-ID^> ^<DEVELOPER-GROUP-OBJECT-ID^>
echo.
echo admin-group-object-id     Entra ID group Object ID mapped to cloud_controller.admin
echo                           (development users -- see WARNING below)
echo developer-group-object-id Entra ID group Object ID mapped to cloud_controller.read
echo                           and cloud_controller.write (developers)
echo saml-origin               UAA identity provider origin name (default: saml)
echo                           -- confirm the actual origin configured for your Entra ID
echo                           SAML integration if this default is wrong.
echo.
echo WARNING: cloud_controller.admin is full Cloud Controller / platform admin --
echo confirm that's really the intended scope for the "development users" group
echo before running this against a foundation.
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
uaac target https://uaa.%SYSTEM_DOMAIN%
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
uaac group map --name cloud_controller.admin --externalgroup %ADMIN_GROUP_ID% --origin %SAML_ORIGIN%
if %ERRORLEVEL% NEQ 0 (
    echo   FAILED: cloud_controller.admin mapping
    set /a FAILCOUNT+=1
) else (
    echo   OK
)

echo === Mapping developer group [%DEVELOPER_GROUP_ID%] to cloud_controller.read ===
uaac group map --name cloud_controller.read --externalgroup %DEVELOPER_GROUP_ID% --origin %SAML_ORIGIN%
if %ERRORLEVEL% NEQ 0 (
    echo   FAILED: cloud_controller.read mapping
    set /a FAILCOUNT+=1
) else (
    echo   OK
)

echo === Mapping developer group [%DEVELOPER_GROUP_ID%] to cloud_controller.write ===
uaac group map --name cloud_controller.write --externalgroup %DEVELOPER_GROUP_ID% --origin %SAML_ORIGIN%
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
echo Next: put the real group Object IDs (not this script's placeholders) into the
echo saml_group: entries in cf-mgmt-config\production\*\spaceConfig.yml so cf-mgmt's
echo org/space role assignment actually resolves to these same groups.

endlocal
