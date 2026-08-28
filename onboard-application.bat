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

echo === Onboarding %APP_NAME% into org %ORG_NAME% ===
echo UI space:  %UI_SPACE%
echo API space: %API_SPACE%
echo Service account: %SERVICE_ACCOUNT%
echo.

echo === Creating spaces ===
cf create-space %UI_SPACE% -o %ORG_NAME%
if %ERRORLEVEL% NEQ 0 (
    echo === Failed to create space %UI_SPACE% ===
    exit /b 1
)

cf create-space %API_SPACE% -o %ORG_NAME%
if %ERRORLEVEL% NEQ 0 (
    echo === Failed to create space %API_SPACE% ===
    exit /b 1
)

echo === Granting %SERVICE_ACCOUNT% SpaceDeveloper on both spaces ===
cf set-space-role %SERVICE_ACCOUNT% %ORG_NAME% %UI_SPACE% SpaceDeveloper
if %ERRORLEVEL% NEQ 0 (
    echo === Failed to set space role on %UI_SPACE% ===
    exit /b 1
)

cf set-space-role %SERVICE_ACCOUNT% %ORG_NAME% %API_SPACE% SpaceDeveloper
if %ERRORLEVEL% NEQ 0 (
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

    cf target -o %ORG_NAME% -s %API_SPACE%
    if %ERRORLEVEL% NEQ 0 (
        echo === Failed to target %ORG_NAME%/%API_SPACE% ===
        exit /b 1
    )

    cf set-space-isolation-segment %API_SPACE% sql-secured-segment
    if %ERRORLEVEL% NEQ 0 (
        echo === Failed to set isolation segment on %API_SPACE% ===
        exit /b 1
    )

    cf bind-security-group SQL-ACCESS-ASG %ORG_NAME% --lifecycle running --space %API_SPACE%
    if %ERRORLEVEL% NEQ 0 (
        echo === Failed to bind SQL-ACCESS-ASG ^(running^) to %API_SPACE% ===
        exit /b 1
    )

    cf bind-security-group SQL-ACCESS-ASG %ORG_NAME% --lifecycle staging --space %API_SPACE%
    if %ERRORLEVEL% NEQ 0 (
        echo === Failed to bind SQL-ACCESS-ASG ^(staging^) to %API_SPACE% ===
        exit /b 1
    )

    echo === Database access configured: %API_SPACE% is in sql-secured-segment and bound to SQL-ACCESS-ASG ===
) else (
    echo === Skipping database access setup -- %UI_SPACE% and %API_SPACE% will use the platform default ASG only ===
)

echo.
echo === Onboarding complete for %APP_NAME% ===
echo   Org:              %ORG_NAME%
echo   Spaces:           %UI_SPACE%, %API_SPACE%
echo   Service account:  %SERVICE_ACCOUNT% ^(SpaceDeveloper on both^)
echo   Database access:  %DB_ACCESS%

endlocal
