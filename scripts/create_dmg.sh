#!/bin/bash
set -e

# Arguments:
# $1 (Optional): Path to existing .app
# $2 (Optional): Output Name for DMG

APP_NAME="Lustra"
DMG_NAME=${2:-"Lustra_Installer.dmg"}
APP_PATH=${1}

if [ -z "$APP_PATH" ]; then
    # No app path provided, perform full build
    SCHEME_NAME="MacCleaner"
    BUILD_DIR="./build"
    APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
    
    echo "🚀 Starting Production Build for $APP_NAME..."
    
    # Allow CODE_SIGN_IDENTITY override from environment
    SIGNING_IDENTITY=${CODE_SIGN_IDENTITY:-"-"}
    REQUIRED_SIGNING=${CODE_SIGNING_REQUIRED:-"YES"}
    
    echo "🔑 Signing with: '$SIGNING_IDENTITY' (Required: $REQUIRED_SIGNING)"
    
    xcodebuild -scheme "$SCHEME_NAME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR" \
        CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
        CODE_SIGNING_REQUIRED="$REQUIRED_SIGNING" \
        clean build || { echo "❌ Build failed"; exit 1; }
        
    echo "✅ Build Successful!"
else
    echo "📦 Using existing App at: $APP_PATH"
fi

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

echo "✨ Production DMG Ready: $DMG_NAME"
