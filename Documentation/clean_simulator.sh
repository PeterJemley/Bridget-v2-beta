#!/bin/bash

# Bridget iOS Simulator Cleanup Script
# Cleans Bridget app from iOS Simulator for fresh testing

echo "🧹 Cleaning Bridget app from iOS Simulator..."

# Find iPhone 16 Pro simulator
SIMULATOR_ID=$(xcrun simctl list devices | grep "iPhone 16 Pro" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ iPhone 16 Pro simulator not found"
    exit 1
fi

echo "📱 Found iPhone 16 Pro simulator: $SIMULATOR_ID"

# Boot simulator if not already running
BOOT_STATUS=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -o "Booted\|Shutdown")
if [ "$BOOT_STATUS" != "Booted" ]; then
    echo "🚀 Booting simulator..."
    xcrun simctl boot "$SIMULATOR_ID"
else
    echo "📱 Simulator already booted"
fi

# Remove Bridget app if installed
echo "🗑️  Removing Bridget app..."
xcrun simctl uninstall "$SIMULATOR_ID" com.peterjemley.Bridget

if [ $? -eq 0 ]; then
    echo "✅ Bridget app successfully removed from simulator"
else
    echo "ℹ️  Bridget app was not installed (this is normal for first run)"
fi

# Clean app data and caches
echo "🧽 Cleaning app data..."
xcrun simctl terminate "$SIMULATOR_ID" com.peterjemley.Bridget 2>/dev/null || true

# Clean derived data for Bridget
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
BRIDGET_DERIVED_DATA=$(find "$DERIVED_DATA_PATH" -name "*Bridget*" -type d 2>/dev/null | head -1)

if [ -n "$BRIDGET_DERIVED_DATA" ]; then
    echo "🗑️  Cleaning derived data: $(basename "$BRIDGET_DERIVED_DATA")"
    rm -rf "$BRIDGET_DERIVED_DATA"
fi

echo "✨ Simulator cleanup complete!"
echo ""
echo "To reinstall Bridget:"
echo "1. Build the project in Xcode"
echo "2. Run on iPhone 16 Pro simulator"
echo "3. Or use: xcodebuild -project Bridget.xcodeproj -scheme Bridget -destination 'platform=iOS Simulator,name=iPhone 16 Pro'" 