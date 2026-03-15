@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  Building qwen3.exe
echo ========================================

cd /d "%~dp0"

:: Step 1: Install dependencies
echo.
echo [1/8] Installing dependencies...
call npm ci --ignore-scripts
if errorlevel 1 (
    echo ERROR: npm ci failed
    exit /b 1
)

:: Step 2: Build packages
echo.
echo [2/8] Building packages...
call npm run build
if errorlevel 1 (
    echo ERROR: build failed
    exit /b 1
)

:: Step 3: Bundle with esbuild (ESM for normal use)
echo.
echo [3/8] Bundling with esbuild...
call npm run bundle
if errorlevel 1 (
    echo ERROR: bundle failed
    exit /b 1
)

:: Step 4: Transform ESM bundle to CJS for SEA
echo.
echo [4/8] Converting ESM to CJS for SEA...
node scripts/esm-to-sea-cjs.js
if errorlevel 1 (
    echo ERROR: ESM to CJS conversion failed
    exit /b 1
)

:: Step 5: Create SEA config
echo.
echo [5/8] Creating SEA config...
node -e "require('fs').writeFileSync('dist/sea-config.json',JSON.stringify({main:'dist/cli-sea.cjs',output:'dist/sea-prep.blob',disableExperimentalSEAWarning:true,useSnapshot:false,useCodeCache:true},null,2))"
if errorlevel 1 (
    echo ERROR: Failed to create SEA config
    exit /b 1
)

:: Step 6: Generate SEA blob
echo.
echo [6/8] Generating SEA blob...
node --experimental-sea-config dist/sea-config.json
if errorlevel 1 (
    echo ERROR: SEA blob generation failed
    exit /b 1
)

:: Step 7: Copy node.exe and inject blob
echo.
echo [7/8] Creating qwen3.exe...
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

:: Step 8: Inject the blob
echo.
echo [8/8] Injecting SEA blob...
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
