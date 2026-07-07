@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Test OM CLI interpolation functionality
REM This script creates test files and demonstrates how OM CLI interpolates variables

echo === Testing OM CLI Interpolation ===
echo.

REM Create test directory
if not exist "test-interpolation" mkdir test-interpolation

REM Create test config.yml with placeholders
echo Creating test config.yml...
echo app_domain: ((domain_name)) > test-interpolation\test-config.yml
echo instances: 3 >> test-interpolation\test-config.yml
echo ssl_enabled: ((ssl_enabled)) >> test-interpolation\test-config.yml

REM Create test vars.yml with values
echo Creating test vars.yml...
echo domain_name: example.com > test-interpolation\test-vars.yml
echo ssl_enabled: invalid >> test-interpolation\test-vars.yml

REM Show original files
echo.
echo === Original Config File ===
REM type test-interpolation\test-config.yml
echo.

echo === Variables File ===
type test-interpolation\test-vars.yml
echo.

REM Test basic interpolation with vars file
echo === Testing basic interpolation with vars file ===
om interpolate -c test-interpolation\test-config.yml -l test-interpolation\test-vars.yml
echo.

REM Test with environment variables
echo === Testing interpolation with environment variables ===
set my_domain_name=env-example.com
set my_ssl_enabled=false

echo Setting environment variables:
echo   domain_name=%my_domain_name%
echo   ssl_enabled=%my_ssl_enabled%
echo.

echo Result with environment variables:
om interpolate -c test-interpolation\test-config.yml --vars-env my
echo.

REM Test combined vars file and environment variables (environment takes precedence)
echo === Testing combined vars file + environment variables ===
echo Environment variables override vars file values:
set my_ssl_enabled=
om interpolate -c test-interpolation\test-config.yml -l test-interpolation\test-vars.yml 
echo.

REM Cleanup
echo === Cleaning up test files ===
REM rmdir /s /q test-interpolation

echo === OM CLI Interpolation Test Complete ===