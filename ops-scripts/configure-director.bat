@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Configure BOSH Director using a configuration file
REM Usage: configure-director.bat <foundation-name> <config-file>

set FOUNDATION=%1
set CONFIG_FILE=%2

if "%FOUNDATION%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<config-file^>
    echo Example: %0 sandbox config-backup\sandbox-20260525-111410\director-config.yml
    exit /b 1
)

if "%CONFIG_FILE%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<config-file^>
    echo Example: %0 sandbox config-backup\sandbox-20260525-111410\director-config.yml
    exit /b 1
)

if not exist "%CONFIG_FILE%" (
    echo Error: Director configuration file not found: %CONFIG_FILE%
    exit /b 1
)

REM Credentials will be loaded by om-command.bat

echo === Configuring BOSH Director for foundation: %FOUNDATION% ===
echo Config file: %CONFIG_FILE%

call ops-scripts\om-command.bat %FOUNDATION% configure-director --config "%CONFIG_FILE%"

if %ERRORLEVEL% EQU 0 (
    echo === BOSH Director configured successfully ===
    echo Run 'apply-changes.bat %FOUNDATION%' to deploy the changes
) else (
    echo === BOSH Director configuration FAILED ===
    echo Error: OM CLI configure-director command failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

endlocal
