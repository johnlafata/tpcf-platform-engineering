@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM set "CRED_FLAG=username"
set "CRED_FLAG=client"
set "ECHO_OPTION=OFF"

REM OM CLI wrapper script that uses explicit credentials for authentication
REM Usage: om-command.bat <foundation-name> [om-cli-arguments...]
REM Example: om-command.bat sandbox staged-products

set FOUNDATION=%1

if "%FOUNDATION%"=="" (
    echo Usage: %0 ^<foundation-name^> [om-cli-arguments...]
    echo Example: %0 sandbox staged-products
    echo Example: %0 sandbox curl -p /api/v0/installations
    exit /b 1
)

REM Load environment variables from om-env.yml
set YML_FILE=env-creds\%FOUNDATION%\om-env.yml
if exist "%YML_FILE%" (
    if /i not "%ECHO_OPTION%"=="OFF" echo Loading configuration from %YML_FILE%

    REM Parse YAML file line by line using native batch commands
    for /f "usebackq tokens=1,* delims=:" %%a in ("%YML_FILE%") do (
        set "key=%%a"
        set "value=%%b"

        REM Remove leading/trailing spaces from value
        for /f "tokens=* delims= " %%v in ("!value!") do set "value=%%v"

        REM Map YAML fields to OM environment variables (skip comments and empty lines)
        if not "!key:~0,1!"=="#" if not "!key!"=="" (
            if /i "!key!"=="target" set "OM_TARGET=!value!"
            if /i "!key!"=="client-id" set "OM_CLIENT_ID=!value!"
            if /i "!key!"=="client-secret" set "OM_CLIENT_SECRET=!value!"
            if /i "!key!"=="username" set "OM_USERNAME=!value!"
            if /i "!key!"=="password" set "OM_PASSWORD=!value!"
        )
    )
) else (
    echo Warning: %YML_FILE% not found. Please ensure OM_TARGET and credentials are set.
    exit /b 1
)

REM Validate credentials based on CRED_FLAG
if /i "%CRED_FLAG%"=="username" (
    if not "%OM_USERNAME%"=="" (
        if /i not "%ECHO_OPTION%"=="OFF" echo OM_USERNAME is set
    ) else (
        echo Warning: OM_USERNAME is not set. Please set it in %YML_FILE% or as an environment variable.
        exit /b 1
    )

    if not "%OM_PASSWORD%"=="" (
        if /i not "%ECHO_OPTION%"=="OFF" echo OM_PASSWORD is set
    ) else (
        echo Warning: OM_PASSWORD is not set. Please set it in %YML_FILE% or as an environment variable.
        exit /b 1
    )
) else if /i "%CRED_FLAG%"=="client" (
    if not "%OM_CLIENT_ID%"=="" (
        if /i not "%ECHO_OPTION%"=="OFF" echo OM_CLIENT_ID is set
    ) else (
        echo Warning: OM_CLIENT_ID is not set. Please set it in %YML_FILE% or as an environment variable.
        exit /b 1
    )

    if not "%OM_CLIENT_SECRET%"=="" (
        if /i not "%ECHO_OPTION%"=="OFF" echo OM_CLIENT_SECRET is set
    ) else (
        echo Warning: OM_CLIENT_SECRET is not set. Please set it in %YML_FILE% or as an environment variable.
        exit /b 1
    )
) else (
    echo Error: Invalid CRED_FLAG value "%CRED_FLAG%". Must be "username" or "client".
    exit /b 1
)

if not "%OM_TARGET%"=="" (
    if /i not "%ECHO_OPTION%"=="OFF" echo OM_TARGET is set
) else (
    echo Warning: OM_TARGET is not set. Please set it in %YML_FILE% or as an environment variable.
    exit /b 1
)

if /i not "%ECHO_OPTION%"=="OFF" echo environment loaded

REM Shift to remove foundation parameter and get remaining arguments
shift
set ARGS=
:collect_args
if "%1"=="" goto args_done
set ARGS=%ARGS% %1
shift
goto collect_args
:args_done

if /i not "%ECHO_OPTION%"=="OFF" echo Command Args: %ARGS%

REM Execute OM CLI with explicit credentials and all remaining arguments
if /i "%CRED_FLAG%"=="username" (
    if /i not "%ECHO_OPTION%"=="OFF" echo om --target %OM_TARGET% /u %OM_USERNAME% /p %OM_PASSWORD% --skip-ssl-validation %ARGS%
    om --target %OM_TARGET% /u %OM_USERNAME% /p %OM_PASSWORD% --skip-ssl-validation %ARGS%
) else if /i "%CRED_FLAG%"=="client" (
    if /i not "%ECHO_OPTION%"=="OFF" echo om -k --target "%OM_TARGET%" /c "%OM_CLIENT_ID%" /s "%OM_CLIENT_SECRET%"  %ARGS%
    uaac token client get %OM_CLIENT_ID% -s %OM_CLIENT_SECRET% >>nul 2>&1
    om -k --target "%OM_TARGET%" /c "%OM_CLIENT_ID%" /s "%OM_CLIENT_SECRET%"  %ARGS%

)
