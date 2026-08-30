@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Onboard an application onto a TAS foundation: creates its -ui/-api space
REM pair, grants the platform service account SpaceDeveloper on both, and --
REM if the app needs database access -- puts the -api space in the
REM SQL-secured isolation segment and binds it to SQL-ACCESS-ASG.
REM
REM This is the manual/scripted equivalent of what cf-mgmt now does
REM declaratively via cf-mgmt-config\<foundation>\<org>\spaces.yml and
REM spaceConfig.yml -- see docs\installation\CF-MGMT-INSTALLATION.md. Use
REM this script for a one-off onboarding outside the cf-mgmt pipeline, or as
REM a reference for what the declarative config needs to reproduce.
REM
REM Usage: onboard-application.bat <app-name> <org-name> [yes^|no] [service-account-user]
REM Example: onboard-application.bat weeklybriefings internal
REM Example: onboard-application.bat weeklybriefings internal yes
REM Example: onboard-application.bat weeklybriefings internal no jenkins-sa
REM
REM   app-name              base name used to derive <app-name>-ui and <app-name>-api spaces
REM   org-name              existing CF org the spaces are created in
REM   yes^|no (optional)    answers "does this app need database access?" non-interactively.
REM                         If omitted, the script asks.
REM   service-account-user  (optional) defaults to jenkins-sa

set APP_NAME=%1
set ORG_NAME=%2
set DB_ACCESS_ARG=%3
set SERVICE_ACCOUNT=%4

if "%SERVICE_ACCOUNT%"=="" set SERVICE_ACCOUNT=jenkins-sa

if "%APP_NAME%"=="" (
    echo Usage: %0 ^<app-name^> ^<org-name^> [yes^|no] [service-account-user]
    echo Example: %0 weeklybriefings internal
    exit /b 1
)

if "%ORG_NAME%"=="" (
    echo Usage: %0 ^<app-name^> ^<org-name^> [yes^|no] [service-account-user]
    echo Example: %0 weeklybriefings internal
    exit /b 1
)

where cf >nul 2>&1
if errorlevel 1 (
    echo Error: cf CLI is required and was not found on PATH.
    exit /b 1
)

cf target >nul 2>&1
if errorlevel 1 (
    echo Error: not logged in to CF. Run "cf login" and target the right API endpoint first.
    exit /b 1
)

set UI_SPACE=%APP_NAME%-ui
set API_SPACE=%APP_NAME%-api
set ISOLATION_SEGMENT=sql-secured-segment

echo === Onboarding %APP_NAME% into org %ORG_NAME% ===
echo UI space:  %UI_SPACE%
echo API space: %API_SPACE%
echo Service account: %SERVICE_ACCOUNT%
echo.

echo === Checking org %ORG_NAME% ===
cf org %ORG_NAME% >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo === Org %ORG_NAME% does not exist, creating it ===
    cf create-org %ORG_NAME%
    REM cf create-org can print OK and still return a nonzero exit code on
    REM some CF CLI versions -- re-check the org's existence directly rather
    REM than trusting create-org's own exit status. Note: !ERRORLEVEL! (delayed
    REM expansion) is required here, not %ERRORLEVEL% -- this check is nested
    REM inside a parenthesized block, and with delayed expansion enabled,
    REM %ERRORLEVEL% would be substituted once at parse time of the whole
    REM outer block (stale), not freshly after the "cf org" line above runs.
    cf org %ORG_NAME% >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo === Failed to create org %ORG_NAME% ===
        exit /b 1
    )
) else (
    echo === Org %ORG_NAME% already exists ===
)

echo === Ensuring org %ORG_NAME% is entitled to isolation segment %ISOLATION_SEGMENT% ===
cf enable-org-isolation %ORG_NAME% %ISOLATION_SEGMENT%
if !ERRORLEVEL! NEQ 0 (
    echo === Failed to enable isolation segment %ISOLATION_SEGMENT% on org %ORG_NAME% ===
    echo Confirm the isolation segment exists on this foundation ^(cf isolation-segments^)
    echo and that you have privileges to entitle it to an org.
    exit /b 1
)

echo === Creating spaces ===
cf create-space %UI_SPACE% -o %ORG_NAME%
if !ERRORLEVEL! NEQ 0 (
    echo === Failed to create space %UI_SPACE% ===
    exit /b 1
)

cf create-space %API_SPACE% -o %ORG_NAME%
if !ERRORLEVEL! NEQ 0 (
    echo === Failed to create space %API_SPACE% ===
    exit /b 1
)

echo === Granting %SERVICE_ACCOUNT% SpaceDeveloper on both spaces ===
cf set-space-role %SERVICE_ACCOUNT% %ORG_NAME% %UI_SPACE% SpaceDeveloper
if !ERRORLEVEL! NEQ 0 (
    echo === Failed to set space role on %UI_SPACE% ===
    exit /b 1
)

cf set-space-role %SERVICE_ACCOUNT% %ORG_NAME% %API_SPACE% SpaceDeveloper
if !ERRORLEVEL! NEQ 0 (
    echo === Failed to set space role on %API_SPACE% ===
    exit /b 1
)

REM Does this app need database access? Accept it non-interactively via the
REM optional third argument, otherwise ask.
if "%DB_ACCESS_ARG%"=="" (
    set /p DB_ACCESS_ARG=Does %APP_NAME% need database access? [y/N]:
)

set DB_ACCESS=no
if /i "%DB_ACCESS_ARG%"=="y" set DB_ACCESS=yes
if /i "%DB_ACCESS_ARG%"=="yes" set DB_ACCESS=yes

if /i "%DB_ACCESS%"=="yes" (
    echo === Configuring database access for %API_SPACE% ===

    REM All four checks below use !ERRORLEVEL! (delayed expansion), not
    REM %ERRORLEVEL% -- they're nested inside this outer "if /i ... (" block,
    REM so with delayed expansion enabled, %ERRORLEVEL% would be frozen at
    REM parse time of the whole block instead of read fresh after each
    REM command, silently skipping real failures.
    cf target -o %ORG_NAME% -s %API_SPACE%
    if !ERRORLEVEL! NEQ 0 (
        echo === Failed to target %ORG_NAME%/%API_SPACE% ===
        exit /b 1
    )

    cf set-space-isolation-segment %API_SPACE% %ISOLATION_SEGMENT%
    if !ERRORLEVEL! NEQ 0 (
        echo === Failed to set isolation segment on %API_SPACE% ===
        exit /b 1
    )

    cf bind-security-group SQL-ACCESS-ASG %ORG_NAME% --lifecycle running --space %API_SPACE%
    if !ERRORLEVEL! NEQ 0 (
        echo === Failed to bind SQL-ACCESS-ASG ^(running^) to %API_SPACE% ===
        exit /b 1
    )

    cf bind-security-group SQL-ACCESS-ASG %ORG_NAME% --lifecycle staging --space %API_SPACE%
    if !ERRORLEVEL! NEQ 0 (
        echo === Failed to bind SQL-ACCESS-ASG ^(staging^) to %API_SPACE% ===
        exit /b 1
    )

    echo === Database access configured: %API_SPACE% is in %ISOLATION_SEGMENT% and bound to SQL-ACCESS-ASG ===
) else (
    echo === Skipping database access setup -- %UI_SPACE% and %API_SPACE% will use the platform default ASG only ===
)

echo.
echo === Onboarding complete for %APP_NAME% ===
echo   Org:              %ORG_NAME% ^(entitled to isolation segment %ISOLATION_SEGMENT%^)
echo   Spaces:           %UI_SPACE%, %API_SPACE%
echo   Service account:  %SERVICE_ACCOUNT% ^(SpaceDeveloper on both^)
echo   Database access:  %DB_ACCESS%

endlocal
