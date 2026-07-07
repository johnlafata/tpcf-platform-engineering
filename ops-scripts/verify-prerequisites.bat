@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "missingCount=0"

echo ================================================
echo Tanzu Platform Automation - Prerequisites Check
echo ================================================
echo.

goto :main

:check_tool
set "toolName=%~1"
set "command=%~2"
set "required=%~3"

set "padding=                    "
set "label=%toolName%!padding%"
set "label=!label:~0,20!"

set "versionLine="

where %command% >nul 2>&1
if %errorlevel%==0 (
    for /f "usebackq delims=" %%A in (`%command% --version 2^>nul`) do if not defined versionLine set "versionLine=%%A"
    if not defined versionLine (
        for /f "usebackq delims=" %%A in (`%command% version 2^>nul`) do if not defined versionLine set "versionLine=%%A"
    )
    if not defined versionLine (
        for /f "usebackq delims=" %%A in (`%command% -v 2^>nul`) do if not defined versionLine set "versionLine=%%A"
    )

    if defined versionLine (
        echo !label! : [OK] Installed (!versionLine!)
    ) else (
        echo !label! : [OK] Installed
    )
    exit /b 0
) else (
    if /i "%required%"=="required" (
        echo !label! : [X] MISSING (REQUIRED)
        set /a missingCount+=1
    ) else (
        echo !label! : [!] Not installed (optional)
    )
    exit /b 1
)

:main
call :check_tool "OM CLI" om required
REM call :check_tool "CredHub CLI" credhub required
REM call :check_tool "BOSH CLI" bosh required
call :check_tool "CF CLI" cf required
call :check_tool "jq" jq required
call :check_tool "git" git required


echo.
echo ================================================

if %missingCount%==0 (
    echo [OK] All required tools are installed!
    echo.
    echo Next steps:
    echo 1. Configure Ops Manager credentials: copy env-creds\sandbox\om-env-redacted.yml env-creds\sandbox\om-env.yml
    echo 2. Edit credentials file: notepad env-creds\sandbox\om-env.yml
    echo 3. Backup existing config: ops-scripts\backup-foundation-config.bat sandbox
    echo 4. Configure BOSH Director: ops-scripts\configure-director.bat sandbox config-backup\^<folder^>\director-config.yml
    echo 5. Apply changes: ops-scripts\apply-changes.bat sandbox p-bosh
    echo 6. See docs\installation\GETTING-STARTED.md for complete workflow
    exit /b 0
) else (
    echo [X] Missing %missingCount% required tool^(s^)
    echo.
    echo Installation instructions:
    echo   See README.md section 'Windows Installation'
    echo.
    echo Download links:
    echo   OM CLI: https://github.com/pivotal-cf/om/releases
REM     echo   CredHub CLI: https://github.com/cloudfoundry/credhub-cli/releases
REM     echo   BOSH CLI: https://github.com/cloudfoundry/bosh-cli/releases
    echo   CF CLI: https://github.com/cloudfoundry/cli/releases
    echo   jq: https://jqlang.github.io/jq/download/
    echo   git: https://git-scm.com/download/win
    exit /b 1
)
