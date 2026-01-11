#!/bin/bash

# Arguments:
# $1 = Old App PID (to wait for)
# $2 = DMG Path (to mount)
# $3 = App Name (e.g. "Lustra")
# $4 = Destination Path (e.g. "/Applications")

OLD_PID=$1
DMG_PATH=$2
APP_NAME=$3
DEST_PATH=$4

echo "Updater: Started. Waiting for PID $OLD_PID to exit..."

# 1. Wait for the host app to terminate
while kill -0 $OLD_PID 2>/dev/null; do
    sleep 0.5
done

echo "Updater: Host app exited. Proceeding with update."

# 2. Mount the DMG
MOUNT_POINT="/Volumes/${APP_NAME}_Update_$(date +%s)"
echo "Updater: Mounting $DMG_PATH to $MOUNT_POINT..."
hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse

if [ ! -d "$MOUNT_POINT" ]; then
    echo "Updater: Failed to mount DMG."
    exit 1
fi

# 3. Remove the old app
TARGET_APP="$DEST_PATH/$APP_NAME.app"
echo "Updater: Removing old app at $TARGET_APP..."
rm -rf "$TARGET_APP"

# 4. Copy the new app
SOURCE_APP="$MOUNT_POINT/$APP_NAME.app"
echo "Updater: Copying new app from $SOURCE_APP to $DEST_PATH..."
cp -R "$SOURCE_APP" "$DEST_PATH/"

# 5. Detach DMG
echo "Updater: Detaching DMG..."
hdiutil detach "$MOUNT_POINT" -force

# 6. Relaunch the App
echo "Updater: Relaunching app..."
open "$TARGET_APP"

echo "Updater: Done."
exit 0
