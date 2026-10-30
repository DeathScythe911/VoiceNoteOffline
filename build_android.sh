#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -d android ]]; then
  echo 'Run tools/setup_mac.sh or Windows setup first.' >&2
  exit 1
fi
flutter pub get
flutter build apk --release --target-platform android-arm64
printf '\nAPK created at build/app/outputs/flutter-apk/app-release.apk\n'
