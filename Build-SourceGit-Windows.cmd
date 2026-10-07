@echo off
setlocal

set "REPO_ROOT=%~dp0"
set "ARTIFACTS_DIR=%REPO_ROOT%artifacts"
set "STAGING_DIR=%ARTIFACTS_DIR%\.sourcegit-package"
set "PUBLISH_DIR=%STAGING_DIR%\SourceGit"
set "ZIP_PATH=%ARTIFACTS_DIR%\sourcegit-nightingames_v1.1.win-x64.zip"

echo Building SourceGit for Windows x64...

where dotnet.exe >nul 2>nul
if errorlevel 1 (
    echo ERROR: .NET SDK not found. Install .NET SDK 10.
    goto :failed
)

if not exist "%REPO_ROOT%depends\AvaloniaEdit\src\AvaloniaEdit\AvaloniaEdit.csproj" (
    where git.exe >nul 2>nul
    if errorlevel 1 (
        echo ERROR: AvaloniaEdit submodule missing and Git not found.
        goto :failed
    )

    echo Initializing Git submodules...
    git -C "%REPO_ROOT%" submodule update --init --recursive
    if errorlevel 1 goto :failed
)

if not exist "%ARTIFACTS_DIR%" mkdir "%ARTIFACTS_DIR%"
if errorlevel 1 goto :failed

set "SOURCEGIT_STAGING_DIR=%STAGING_DIR%"
set "SOURCEGIT_PUBLISH_DIR=%PUBLISH_DIR%"
set "SOURCEGIT_ZIP_PATH=%ZIP_PATH%"

if exist "%STAGING_DIR%" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
        "$ErrorActionPreference = 'Stop'; Remove-Item -LiteralPath $env:SOURCEGIT_STAGING_DIR -Recurse -Force"
    if errorlevel 1 goto :failed
)

if exist "%ZIP_PATH%" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
        "$ErrorActionPreference = 'Stop'; Remove-Item -LiteralPath $env:SOURCEGIT_ZIP_PATH -Force"
    if errorlevel 1 goto :failed
)

dotnet build-server shutdown >nul
dotnet publish "%REPO_ROOT%src\SourceGit.csproj" ^
    -c Release ^
    -r win-x64 ^
    -o "%PUBLISH_DIR%" ^
    -p:DisableAOT=true ^
    --self-contained true ^
    --disable-build-servers
if errorlevel 1 goto :failed

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; Get-ChildItem -LiteralPath $env:SOURCEGIT_PUBLISH_DIR -Filter *.pdb -File -Recurse | Remove-Item -Force"
if errorlevel 1 goto :failed

if not exist "%PUBLISH_DIR%\SourceGit.exe" (
    echo ERROR: Publish completed without SourceGit.exe.
    goto :failed
)
if not exist "%PUBLISH_DIR%\coreclr.dll" (
    echo ERROR: Publish is not self-contained; coreclr.dll missing.
    goto :failed
)
if not exist "%PUBLISH_DIR%\hostfxr.dll" (
    echo ERROR: Publish is not self-contained; hostfxr.dll missing.
    goto :failed
)
if not exist "%PUBLISH_DIR%\hostpolicy.dll" (
    echo ERROR: Publish is not self-contained; hostpolicy.dll missing.
    goto :failed
)

echo Creating ZIP...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; Compress-Archive -LiteralPath $env:SOURCEGIT_PUBLISH_DIR -DestinationPath $env:SOURCEGIT_ZIP_PATH -CompressionLevel Optimal -Force"
if errorlevel 1 goto :failed

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; $zip = Get-Item -LiteralPath $env:SOURCEGIT_ZIP_PATH; $stream = [IO.File]::OpenRead($zip.FullName); try { $sha = [Security.Cryptography.SHA256]::Create(); try { $hash = -join ($sha.ComputeHash($stream) | ForEach-Object { $_.ToString('X2') }) } finally { $sha.Dispose() } } finally { $stream.Dispose() }; Write-Host ('Created: ' + $zip.FullName); Write-Host ('Size:    ' + [math]::Round($zip.Length / 1MB, 2) + ' MB'); Write-Host ('SHA-256: ' + $hash)"
if errorlevel 1 goto :failed

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; Remove-Item -LiteralPath $env:SOURCEGIT_STAGING_DIR -Recurse -Force"
if errorlevel 1 goto :failed

echo Build and package succeeded.
goto :done

:failed
echo.
echo Build or package failed.
if /I not "%~1"=="--no-pause" pause
exit /b 1

:done
if /I not "%~1"=="--no-pause" pause
exit /b 0
