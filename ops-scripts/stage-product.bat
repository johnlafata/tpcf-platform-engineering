@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Stage an already-uploaded product tile in Ops Manager
REM Usage: stage-product.bat <foundation-name> <product-name> <product-version>

set FOUNDATION=%1
set PRODUCT_NAME=%2
set PRODUCT_VERSION=%3

if "%FOUNDATION%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<product-name^> ^<product-version^>
    echo Example: %0 sandbox cf 10.0.5
    exit /b 1
)

if "%PRODUCT_NAME%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<product-name^> ^<product-version^>
    echo Example: %0 sandbox cf 10.0.5
    exit /b 1
)

if "%PRODUCT_VERSION%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<product-name^> ^<product-version^>
    echo Example: %0 sandbox cf 10.0.5
    exit /b 1
)

REM Credentials will be loaded by om-command.bat

echo === Staging product for foundation: %FOUNDATION% ===
echo Product: %PRODUCT_NAME% v%PRODUCT_VERSION%

echo Staging product...
call ops-scripts\om-command.bat %FOUNDATION% stage-product --product-name %PRODUCT_NAME% --product-version %PRODUCT_VERSION%

if %ERRORLEVEL% EQU 0 (
    echo === Product staged successfully ===
    echo Run 'configure-product.bat %FOUNDATION% %PRODUCT_NAME%' to configure and deploy
) else (
    echo === Product staging FAILED ===
    echo Error: OM CLI stage command failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)
