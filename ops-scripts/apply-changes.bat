@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Apply changes to deploy products
REM Usage: apply-changes.bat <foundation-name> [product-name]

set FOUNDATION=%1
set PRODUCT=%2

if "%FOUNDATION%"=="" (
    echo Usage: %0 ^<foundation-name^> [product-name]
    echo Example: %0 sandbox          # Apply changes to all products
    echo Example: %0 sandbox cf       # Apply changes to cf only
    exit /b 1
)

REM Credentials will be loaded by om-command.bat

echo === Applying changes for foundation: %FOUNDATION% ===

if not "%PRODUCT%"=="" (
    echo Deploying product: %PRODUCT%
    call ops-scripts\om-command.bat %FOUNDATION% apply-changes --product-name %PRODUCT%
) else (
    echo Deploying all staged products
    call ops-scripts\om-command.bat %FOUNDATION% apply-changes
)

if %ERRORLEVEL% EQU 0 (
    echo === Changes applied successfully ===
) else (
    echo === Changes application FAILED ===
    echo Error: OM CLI command failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)
