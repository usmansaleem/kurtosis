@echo off
REM setup.bat - Automated setup script for CallTracer test environment (Windows)

echo ======================================
echo CallTracer Testing Suite Setup
echo ======================================
echo.

REM Check for Python 3
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python 3 is not installed
    echo Please install Python 3.10+ and try again
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version') do set PYTHON_VERSION=%%i
echo Found Python %PYTHON_VERSION%

REM Check for required tools
echo.
echo Checking required tools...

kurtosis version >nul 2>&1
if errorlevel 1 (
    echo Error: Kurtosis is not installed
    echo Install from: https://docs.kurtosis.com/install
    exit /b 1
)
echo Kurtosis installed

forge --version >nul 2>&1
if errorlevel 1 (
    echo Error: Foundry ^(forge^) is not installed
    echo Install from: https://getfoundry.sh/
    exit /b 1
)
echo Foundry installed

REM Initialize git submodules
echo.
echo Initializing git submodules...
if exist .gitmodules (
    git submodule update --init --recursive
    echo Submodules initialized
) else (
    echo No .gitmodules found, skipping
)

REM Create virtual environment
echo.
echo Creating Python virtual environment...
if exist venv (
    echo Virtual environment already exists
    set /p RECREATE="Do you want to recreate it? (y/n) "
    if /i "%RECREATE%"=="y" (
        rmdir /s /q venv
        python -m venv venv
        echo Virtual environment recreated
    ) else (
        echo Using existing virtual environment
    )
) else (
    python -m venv venv
    echo Virtual environment created
)

REM Activate virtual environment and install dependencies
echo.
echo Installing Python dependencies...

call venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt

echo Dependencies installed

REM Summary
echo.
echo ======================================
echo Setup Complete!
echo ======================================
echo.
echo To activate the virtual environment:
echo.
echo   venv\Scripts\activate
echo.
echo Then you can run the tests:
echo.
echo   python kurtosis_manager.py start
echo   python call_tracer_tests.py
echo   python kurtosis_manager.py stop
echo.
echo See README.md for more information.
echo.

pause
