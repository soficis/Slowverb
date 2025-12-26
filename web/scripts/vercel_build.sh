#!/bin/bash
set -e

echo "--------------------------------------------------------------------------------"
echo "Starting Vercel Build Script"
echo "--------------------------------------------------------------------------------"

# 1. Install Flutter
# Check if cached
if [ -d ".flutter_sdk" ]; then
    echo "Flutter SDK found in cache."
    export PATH="$PATH:`pwd`/.flutter_sdk/bin"
    flutter --version
else
    echo "Installing Flutter..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable .flutter_sdk
    export PATH="$PATH:`pwd`/.flutter_sdk/bin"
fi

# 2. Project Setup
echo "Running flutter doctor..."
flutter doctor -v

echo "Getting Flutter packages..."
flutter pub get

# 3. Build Dependencies (TypeScript)
# Assumes npm install has already run by Vercel
echo "Building TypeScript packages..."
npm run build:ts

# 4. Sync Assets
echo "Syncing bridge assets..."
npm run sync:bridge

# 5. Build Flutter Web App
echo "Building Flutter Web application (WASM + Release)..."
flutter build web --wasm --release --verbose

# 6. Copy JavaScript/WASM assets to build output
# These files (phaselimiter_pro.wasm, etc.) are not handled by Flutter
echo "Copying JS/WASM assets to build directory..."
cp -rv web/js/* build/web/js/

echo "Build complete! Output directory: build/web"
