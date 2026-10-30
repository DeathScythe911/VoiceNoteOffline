#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --platforms=android,ios --org com.offlinevoice --project-name voice_note_offline .
python3 tools/configure_project.py
flutter pub get
printf '\nSetup complete. See README for iOS Share Extension / signing setup.\n'
