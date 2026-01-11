#!/bin/bash
set -e

APP_NAME="Lustra"
SCHEME_NAME="MacCleaner"
DMG_NAME="Lustra_Installer.dmg"
BUILD_DIR="./build"
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

echo "🚀 Starting Production Build for $APP_NAME..."

# 1. Clean and Build in Release Mode
xcodebuild -scheme "$SCHEME_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    clean build || { echo "❌ Build failed"; exit 1; }

echo "✅ Build Successful!"

# 2. Prepare staging area for DMG
STAGING_DIR="./dmg_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "📂 Preparing DMG contents..."
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 3. Create DMG
echo "📦 Packaging $DMG_NAME..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME Installer" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

echo "🧹 Cleaning up..."
rm -rf "$STAGING_DIR"
# Optional: keep build dir or clean it
# rm -rf "$BUILD_DIR"

echo "✨ Production DMG Ready: $DMG_NAME"
