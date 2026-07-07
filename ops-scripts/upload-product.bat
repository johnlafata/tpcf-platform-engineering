@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Upload a product tile to Ops Manager
REM Usage: upload-product.bat <foundation-name> <product-file>

set FOUNDATION=%1
set PRODUCT_FILE=%2

if "%FOUNDATION%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<product-file^>
    echo Example: %0 sandbox .\cf-10.0.5.pivotal
    exit /b 1
)

if "%PRODUCT_FILE%"=="" (
    echo Usage: %0 ^<foundation-name^> ^<product-file^>
    echo Example: %0 sandbox .\cf-10.0.5.pivotal
    exit /b 1
)

if not exist "%PRODUCT_FILE%" (
    echo Error: Product file not found: %PRODUCT_FILE%
    exit /b 1
)

REM Credentials will be loaded by om-command.bat

echo === Uploading product for foundation: %FOUNDATION% ===
echo File: %PRODUCT_FILE%

echo Uploading product tile...
call ops-scripts\om-command.bat %FOUNDATION% upload-product --product %PRODUCT_FILE%

if %ERRORLEVEL% EQU 0 (
    echo === Product uploaded successfully ===
    echo Run 'stage-product.bat %FOUNDATION% ^<product-name^> ^<product-version^>' to stage the product
) else (
    echo === Product upload FAILED ===
    echo Error: OM CLI upload command failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)
