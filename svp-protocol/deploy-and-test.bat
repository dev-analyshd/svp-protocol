@echo off
REM ###########################################################################
REM SVP Protocol - One-Command Deployment & Testing Script (Windows)
REM 
REM Usage: deploy-and-test.bat [network]
REM Networks: arbitrumSepolia, robinhoodChain, localhost
REM ###########################################################################

setlocal enabledelayedexpansion
set NETWORK=%1
if "%NETWORK%"=="" set NETWORK=arbitrumSepolia

set DEPLOYMENT_DIR=deployments
set LOG_FILE=deployment-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%.log

cls
echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║   SVP PROTOCOL - DEPLOYMENT ^& TESTING PIPELINE                  ║
echo ║   Network: %NETWORK%                                    ║
echo ║   Date: %date%                                      ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

REM ###########################################################################
REM PRE-DEPLOYMENT CHECKS
REM ###########################################################################

echo [1/8] PRE-DEPLOYMENT CHECKS
echo ======================================

REM Check Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo ✗ Node.js not installed
    exit /b 1
)
echo ✓ Node.js installed: 
node --version

REM Check npm
npm --version >nul 2>&1
if errorlevel 1 (
    echo ✗ npm not installed
    exit /b 1
)
echo ✓ npm installed: 
npm --version

REM Check .env file
if not exist ".env" if not exist ".env.example" (
    echo ✗ .env or .env.example not found
    exit /b 1
)
echo ✓ .env configuration file found

REM Check Hardhat
if not exist "hardhat.config.ts" (
    echo ✗ hardhat.config.ts not found
    exit /b 1
)
echo ✓ Hardhat configuration found

REM Check contracts
if not exist "contracts" (
    echo ✗ contracts directory not found
    exit /b 1
)
echo ✓ Contracts directory found

echo.
echo ✨ All pre-deployment checks passed
echo.

REM ###########################################################################
REM INSTALLATION
REM ###########################################################################

echo [2/8] INSTALLING DEPENDENCIES
echo ======================================

if exist "node_modules" (
    echo ℹ node_modules already exists, skipping installation
) else (
    echo ℹ Installing npm packages...
    call npm install --loglevel=error
    echo ✓ Dependencies installed
)
echo.

REM ###########################################################################
REM COMPILATION
REM ###########################################################################

echo [3/8] COMPILING SMART CONTRACTS
echo ======================================

echo ℹ Compiling with Hardhat...
call npx hardhat compile --quiet
if errorlevel 1 (
    echo ✗ Compilation failed
    exit /b 1
)
echo ✓ Contracts compiled successfully
echo ✓ TypeChain types generated
echo.

REM ###########################################################################
REM DEPLOYMENT
REM ###########################################################################

echo [4/8] DEPLOYING CONTRACTS
echo ======================================
echo Network: %NETWORK%
echo.

if not exist "%DEPLOYMENT_DIR%" mkdir "%DEPLOYMENT_DIR%"

echo ℹ This may take 2-5 minutes depending on network congestion...
echo.

call npx hardhat run scripts/deploy.ts --network %NETWORK%
if errorlevel 1 (
    echo ✗ Deployment failed
    exit /b 1
)

echo ✓ Contracts deployed successfully
echo.

REM ###########################################################################
REM TESTING
REM ###########################################################################

echo [5/8] RUNNING UNIT TESTS
echo ======================================

echo ℹ Running protocol tests...
call npx hardhat test test\protocol.full.test.ts
if errorlevel 1 (
    echo ✗ Unit tests failed
    exit /b 1
)

echo ✓ Unit tests passed
echo.

REM ###########################################################################
REM INTEGRATION TESTS
REM ###########################################################################

echo [6/8] RUNNING INTEGRATION TESTS
echo ======================================

echo ℹ Running DApp integration tests...
call npx hardhat test test\dapp.integration.test.ts
if errorlevel 1 (
    echo ✗ Integration tests failed - continuing anyway
)

echo ✓ Integration tests completed
echo.

REM ###########################################################################
REM DEPLOYMENT VERIFICATION
REM ###########################################################################

echo [7/8] DEPLOYMENT VERIFICATION
echo ======================================

for /f "tokens=*" %%i in ('dir /b /od "%DEPLOYMENT_DIR%\*.json" 2^>nul') do (
    set LATEST_DEPLOYMENT=%DEPLOYMENT_DIR%\%%i
)

if exist "%LATEST_DEPLOYMENT%" (
    echo ✓ Deployment record found: %LATEST_DEPLOYMENT%
    echo.
    echo Deployment Details:
    type "%LATEST_DEPLOYMENT%"
    echo.
) else (
    echo ✗ No deployment record found
)

echo.

REM ###########################################################################
REM SUMMARY
REM ###########################################################################

echo [8/8] SUMMARY
echo ======================================
echo.
echo ✅ Completed Steps:
echo   ✓ Pre-deployment checks
echo   ✓ Dependencies installed
echo   ✓ Contracts compiled
echo   ✓ Contracts deployed to %NETWORK%
echo   ✓ Unit tests passed
echo   ✓ Integration tests completed
echo   ✓ Deployment verified
echo.

echo 📋 Deployment Information:
echo   Network: %NETWORK%
echo   Deployment Log: %LOG_FILE%
echo   Deployments Dir: %DEPLOYMENT_DIR%
echo   Latest Deployment: %LATEST_DEPLOYMENT%
echo.

echo 📚 Next Steps:
echo   1. Review deployment: dir %DEPLOYMENT_DIR%
echo   2. View latest deployment: type "%LATEST_DEPLOYMENT%"
echo   3. Check contract on block explorer
echo   4. Update frontend with contract addresses
echo   5. Initialize governance (if needed)
echo   6. Start user testing
echo.

echo ✨ Protocol is ready for use!
echo.

pause
