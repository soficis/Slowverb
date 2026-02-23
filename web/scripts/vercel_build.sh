#!/usr/bin/env bash
set -euo pipefail

npm run build

if command -v flutter >/dev/null 2>&1; then
  flutter pub get --enforce-lockfile
  flutter build web --release --no-pub
  exit 0
fi

echo "flutter not found; deploying prebuilt web/ assets"
rm -rf build/web
mkdir -p build
cp -a web/. build/web/
