@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Configure a staged product tile using parameterized configuration
REM Usage: configure-product.bat <foundation-name> <product-name> <config-file>

set FOUNDATION=%1
set CONFIG_FILE=%2

if "%FOUNDATION%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<product-name^>
    echo Example: %0 sandbox cf
    echo Example: %0 prod isolation-segment
    exit /b 1
)

REM Credentials will be loaded by om-command.bat

REM Check for required files
REM set CONFIG_FILE=products\%PRODUCT%\config.yml
REM set VARS_FILE=environments\%FOUNDATION%\%PRODUCT%-vars.yml

if "%CONFIG_FILE%"=="" (
    echo Usage: %0 ^<foundation-name^>  ^<config-file^>
    echo Example: %0 sandbox  ^<config-file^>
    exit /b 1
)

if not exist "%CONFIG_FILE%" (
    echo Error: Product configuration not found: %CONFIG_FILE%
    exit /b 1
)

REM if not exist "%VARS_FILE%" (
REM    echo Error: Product variables not found: %VARS_FILE%
REM    exit /b 1
REM )

echo === Configuring %PRODUCT% for foundation: %FOUNDATION% ===
echo Config:    %CONFIG_FILE%
REM echo Vars file: %VARS_FILE%

REM call ops-scripts\om-command.bat %FOUNDATION% configure-product ^
REM  --config "%CONFIG_FILE%" ^
REM  --vars-file "%VARS_FILE%" ^
REM  --vars-env %FOUNDATION%

call ops-scripts\om-command.bat %FOUNDATION% configure-product /c "%CONFIG_FILE%" 


if %ERRORLEVEL% EQU 0 (
    echo === configured successfully ===
    echo Run 'apply-changes.bat %FOUNDATION% %PRODUCT%' to deploy the changes
) else (
    echo === configuration FAILED ===
    echo Error: OM CLI configure-product command failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

endlocal
