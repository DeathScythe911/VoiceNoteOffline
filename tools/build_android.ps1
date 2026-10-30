$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path 'android')) { throw 'Run tools/setup_windows.ps1 first.' }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
flutter build apk --release --target-platform android-arm64
if ($LASTEXITCODE -ne 0) { throw 'Android build failed' }
Write-Host 'APK: build/app/outputs/flutter-apk/app-release.apk'
