@echo off
REM SVP Protocol - GitHub Push Script for Windows PowerShell
REM Run from capitalBridge directory

setlocal enabledelayedexpansion

echo.
echo ========================================
echo SVP Protocol - GitHub Push Utility
echo ========================================
echo.

cd /d "C:\Users\ALBASH SOLUTION\Music\capitalBridge"

REM Check if git is installed
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Git is not installed or not in PATH
    echo Please install Git from: https://git-scm.com/download/win
    pause
    exit /b 1
)

echo Step 1: Initializing git repository...
git init
if %errorlevel% neq 0 (
    echo Error during git init
    pause
    exit /b 1
)

echo Step 2: Configuring git...
set /p GIT_NAME="Enter your name: "
set /p GIT_EMAIL="Enter your email: "
git config user.name "%GIT_NAME%"
git config user.email "%GIT_EMAIL%"

echo Step 3: Adding all files...
git add .
if %errorlevel% neq 0 (
    echo Error during git add
    pause
    exit /b 1
)

echo Step 4: Creating initial commit...
git commit -m "Initial commit: SVP Protocol - Smart Contracts, DApp, and SDK"
if %errorlevel% neq 0 (
    echo Error during git commit
    pause
    exit /b 1
)

echo Step 5: Adding GitHub remote...
set /p GITHUB_REPO="Enter GitHub repository URL (https://github.com/username/repo): "
git remote add origin %GITHUB_REPO%
if %errorlevel% neq 0 (
    echo Error adding remote
    pause
    exit /b 1
)

echo Step 6: Renaming branch to main...
git branch -M main
if %errorlevel% neq 0 (
    echo Error renaming branch
    pause
    exit /b 1
)

echo Step 7: Pushing to GitHub...
echo Note: You may be prompted for authentication
git push -u origin main
if %errorlevel% neq 0 (
    echo Error during push - check your authentication
    echo If using HTTPS, you may need a Personal Access Token
    echo If using SSH, ensure your key is configured
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ Successfully pushed to GitHub!
echo ========================================
echo.
echo Repository: %GITHUB_REPO%
echo Branch: main
echo.
echo Next steps:
echo 1. Update README.md in GitHub with your details
echo 2. Add GitHub Actions for CI/CD
echo 3. Configure repository settings
echo 4. Deploy to testnet: npm run deploy:arb
echo.
pause
