@echo off
REM Backup configuration for all products in a foundation
REM Usage: backup-foundation-config.bat <foundation-name>

setlocal enabledelayedexpansion

set FOUNDATION=%1

if "%FOUNDATION%"=="" (
  echo Usage: %0 ^<foundation-name^>
  echo Example: %0 sandbox
  exit /b 1
)

REM Generate timestamp for backup directory
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "TIMESTAMP=%dt:~0,8%-%dt:~8,6%"
set "BACKUP_DIR=config-backup\%FOUNDATION%-%TIMESTAMP%"

REM Credentials will be loaded by om-command.bat

echo === Backing up configuration for foundation: %FOUNDATION% ===
echo Backup directory: %BACKUP_DIR%

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

REM Backup director configuration
echo Backing up BOSH Director configuration...
call ops-scripts\om-command.bat %FOUNDATION% staged-director-config --no-redact > "%BACKUP_DIR%\director-config.yml"

REM Get list of staged products
echo Getting list of staged products...
call ops-scripts\om-command.bat %FOUNDATION% staged-products --format json > temp_products.json

REM Note: Windows batch has limited JSON parsing. Consider using PowerShell or jq for Windows
REM For simplicity, backup common products
echo "make sure the list of products is correct - currently cf VMware-NSX-T p-healthwatch2-pas-exporter p-healthwatch2 p-isolation-segment"
echo "then REM out this next line"
REM exit
for %%p in (cf VMware-NSX-T p-healthwatch2-pas-exporter p-healthwatch2 p-isolation-segment) do (
  echo Checking for %%p...
  call ops-scripts\om-command.bat %FOUNDATION% staged-config --include-credentials -p %%p -c > "%BACKUP_DIR%\%%p-config.yml" 2>nul
  if errorlevel 1 (
    echo Product %%p not found, skipping...
    del "%BACKUP_DIR%\%%p-config.yml" 2>nul
  ) else (
    echo Backed up %%p configuration
  )
)

if exist temp_products.json del temp_products.json

echo === Backup completed successfully ===
echo Backup location: %BACKUP_DIR%

endlocal
