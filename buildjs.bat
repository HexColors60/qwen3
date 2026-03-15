@echo off
setlocal

echo ========================================
echo  Building qwen (JS bundle)
echo ========================================

cd /d "%~dp0"

:: Step 1: Install dependencies
echo.
echo [1/3] Installing dependencies...
call npm ci --ignore-scripts
if errorlevel 1 (
    echo ERROR: npm ci failed
    exit /b 1
)

:: Step 2: Build packages
echo.
echo [2/3] Building packages...
call npm run build
if errorlevel 1 (
    echo ERROR: build failed
    exit /b 1
)

:: Step 3: Bundle with esbuild
echo.
echo [3/3] Bundling with esbuild...
call npm run bundle
if errorlevel 1 (
    echo ERROR: bundle failed
    exit /b 1
)

echo.
echo ========================================
echo  Build complete: dist\cli.js
echo  Run with: node dist\cli.js
echo ========================================
echo.

endlocal
