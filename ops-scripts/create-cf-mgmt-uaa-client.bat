@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Create (or update) the UAA client cf-mgmt needs to manage a TAS foundation.
REM Pulls the UAA admin client credentials from Ops Manager itself (om credentials),
REM so no admin secret has to be typed in or stored by hand.
REM
REM Usage: create-cf-mgmt-uaa-client.bat <foundation-name> <system-domain> [cf-mgmt-client-secret]
REM Example: create-cf-mgmt-uaa-client.bat production sys.agi-explorer.com
REM Example: create-cf-mgmt-uaa-client.bat production sys.agi-explorer.com MySecret123

set FOUNDATION=%1
set SYSTEM_DOMAIN=%2
set CF_MGMT_SECRET=%3

if "%FOUNDATION%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<system-domain^> [cf-mgmt-client-secret]
    echo Example: %0 production sys.agi-explorer.com
    exit /b 1
)

if "%SYSTEM_DOMAIN%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<system-domain^> [cf-mgmt-client-secret]
    echo Example: %0 production sys.agi-explorer.com
    echo.
    echo system-domain is the TAS foundation's system domain (e.g. sys.agi-explorer.com^),
    echo not the Ops Manager URL. cf-mgmt authenticates against https://uaa.SYSTEM-DOMAIN,
    echo which is a different UAA than the one om-command.bat talks to for Ops Manager itself.
    exit /b 1
)

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

REM Generate a secret for the cf-mgmt client if one wasn't passed in
if "%CF_MGMT_SECRET%"=="" (
    for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "[guid]::NewGuid().ToString()"`) do set CF_MGMT_SECRET=%%i
    echo Generated a new cf-mgmt client secret.
)

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

REM authorities cf-mgmt needs. routing.router_groups.read uses an UNDERSCORE
REM between "router" and "groups" -- routing.router-groups.read (hyphen) looks
REM plausible and UAA will store it with no error, but it doesn't match anything
REM the Routing API checks for, so export-config/apply fail at the last step with
REM "Getting routing groups: unauthorized" -- see docs\installation\CF-MGMT-INSTALLATION.md
set AUTHORITIES=cloud_controller.admin,scim.read,scim.write,clients.read,clients.write,clients.secret,clients.admin,uaa.admin,routing.router_groups.read

uaac client get cf-mgmt >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo === cf-mgmt client already exists, updating authorities ===
    uaac client update cf-mgmt --authorities %AUTHORITIES%
) else (
    echo === Creating cf-mgmt client ===
    uaac client add cf-mgmt --secret %CF_MGMT_SECRET% --authorized_grant_types client_credentials --authorities %AUTHORITIES%
)

if %ERRORLEVEL% NEQ 0 (
    echo === cf-mgmt client create/update FAILED ===
    exit /b %ERRORLEVEL%
)

echo === Verifying authorities landed correctly ===
uaac client get cf-mgmt > "%TEMP%\cf-mgmt-client-%FOUNDATION%.txt"
findstr /c:"routing.router_groups.read" "%TEMP%\cf-mgmt-client-%FOUNDATION%.txt" >nul
if %ERRORLEVEL% NEQ 0 (
    echo === WARNING: routing.router_groups.read is missing from cf-mgmt's authorities ===
    echo This usually means %ADMIN_CLIENT_ID% doesn't hold that scope itself -- a UAA
    echo client generally can't grant a scope it doesn't already have, uaa.admin included.
    echo See "Getting routing groups: unauthorized" in docs\installation\CF-MGMT-INSTALLATION.md
    type "%TEMP%\cf-mgmt-client-%FOUNDATION%.txt"
    del "%TEMP%\cf-mgmt-client-%FOUNDATION%.txt" 2>nul
    exit /b 1
)
del "%TEMP%\cf-mgmt-client-%FOUNDATION%.txt" 2>nul

REM Save alongside the OM credentials this repo already keeps per foundation
set CF_MGMT_ENV_FILE=env-creds\%FOUNDATION%\cf-mgmt-env.yml
if not exist "env-creds\%FOUNDATION%" mkdir "env-creds\%FOUNDATION%"
(
    echo # cf-mgmt-env.yml
    echo # Generated by create-cf-mgmt-uaa-client.bat -- do not commit real secrets to git
    echo system-domain: %SYSTEM_DOMAIN%
    echo client-id: cf-mgmt
    echo client-secret: %CF_MGMT_SECRET%
) > "%CF_MGMT_ENV_FILE%"

echo === cf-mgmt UAA client ready ===
echo Saved to %CF_MGMT_ENV_FILE% ^(gitignored via env-creds/**/cf-mgmt-env.yml in .gitignore^)
echo.
echo Next: validate with a read-only export, per docs\installation\CF-MGMT-INSTALLATION.md
echo ^(export-config requires ldap.yml to already exist in --config-dir, even though
echo this setup doesn't use LDAP sync^):
echo   mkdir cf-mgmt-config\%FOUNDATION%_client-check
echo   echo enabled: false ^> cf-mgmt-config\%FOUNDATION%_client-check\ldap.yml
echo   cf-mgmt export-config --config-dir=cf-mgmt-config\%FOUNDATION%_client-check --system-domain=%SYSTEM_DOMAIN% --user-id=cf-mgmt --client-secret=%CF_MGMT_SECRET%

endlocal
