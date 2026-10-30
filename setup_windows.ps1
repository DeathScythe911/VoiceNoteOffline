$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
Write-Host 'Generating Android and iOS Flutter projects...'
flutter create --platforms=android,ios --org com.offlinevoice --project-name voice_note_offline .
if ($LASTEXITCODE -ne 0) { throw 'flutter create failed' }
py -3 tools/configure_project.py
if ($LASTEXITCODE -ne 0) { throw 'Project configuration failed. Install Python 3.' }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
Write-Host 'Setup complete. Build Android: flutter build apk --release --target-platform android-arm64'
Write-Host 'Use a Mac with Xcode for the separate iOS build.'
