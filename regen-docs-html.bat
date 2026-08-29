@echo off
setlocal EnableExtensions

REM Regenerate the .html companion next to every .md file in this repo, so
REM docs are readable by double-clicking (opens in the default browser) on a
REM Windows jumphost with no Markdown-aware application associated with .md
REM files. Markdown stays the source of truth -- re-run this after editing
REM any .md file. Pure Python standard library, no pip installs required.
REM
REM Usage: regen-docs-html.bat

where python >nul 2>&1
if errorlevel 1 (
    where python3 >nul 2>&1
    if errorlevel 1 (
        echo Error: python ^(or python3^) is required and was not found on PATH.
        exit /b 1
    )
    set PYTHON_CMD=python3
) else (
    set PYTHON_CMD=python
)

%PYTHON_CMD% "%~dp0regen-docs-html.py" "%~dp0"
