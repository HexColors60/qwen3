@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  Building qwen3.exe
echo ========================================

cd /d "%~dp0"

:: Step 1: Install dependencies
echo.
echo [1/7] Installing dependencies...
call npm ci
if errorlevel 1 (
    echo ERROR: npm ci failed
    exit /b 1
)

:: Step 2: Build packages
echo.
echo [2/7] Building packages...
call npm run build
if errorlevel 1 (
    echo ERROR: build failed
    exit /b 1
)

:: Step 3: Bundle with esbuild
echo.
echo [3/7] Bundling with esbuild...
call npm run bundle
if errorlevel 1 (
    echo ERROR: bundle failed
    exit /b 1
)

:: Step 4: Create SEA config (ESM, no code cache - required for top-level await)
echo.
echo [4/7] Creating SEA config...
(
echo {
echo   "main": "dist/cli.js",
echo   "output": "dist/sea-prep.blob",
echo   "disableExperimentalSEAWarning": true,
echo   "useSnapshot": false,
echo   "useCodeCache": false
echo }
) > dist\sea-config.json

:: Step 5: Generate SEA blob
echo.
echo [5/7] Generating SEA blob...
node --experimental-sea-config dist/sea-config.json
if errorlevel 1 (
    echo ERROR: SEA blob generation failed
    exit /b 1
)

:: Step 6: Copy node.exe and inject blob
echo.
echo [6/7] Creating qwen3.exe...
copy /y "%~dp0node_modules\node\bin\node.exe" dist\qwen3.exe >nul 2>&1
if errorlevel 1 (
    :: Fallback: copy from system node
    where node >nul 2>&1
    if errorlevel 1 (
        echo ERROR: node.exe not found
        exit /b 1
    )
    for /f "delims=" %%i in ('where node') do set "NODE_PATH=%%i"
    copy /y "!NODE_PATH!" dist\qwen3.exe >nul
)

:: Remove signature (required for SEA injection on Windows)
signtool remove /s dist\qwen3.exe >nul 2>&1

:: Step 7: Inject the blob
echo.
echo [7/7] Injecting SEA blob...
npx --yes postject dist/qwen3.exe NODE_SEA_BLOB dist/sea-prep.blob --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2
if errorlevel 1 (
    echo ERROR: postject injection failed
    exit /b 1
)

:: Copy native addons alongside exe
echo.
echo Copying native addons...
for /r node_modules %%f in (*.node) do (
    echo   Copying %%~nxf
    copy /y "%%f" dist\ >nul 2>&1
)

:: Copy vendor directory (ripgrep etc.)
if exist dist\vendor (
    echo Vendor directory already present.
) else (
    echo WARNING: dist\vendor not found - ripgrep may not work.
)

echo.
echo ========================================
echo  Build complete: dist\qwen3.exe
echo ========================================
echo.

endlocal
