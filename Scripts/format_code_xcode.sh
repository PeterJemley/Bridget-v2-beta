#!/bin/bash

# Script to format all Swift code files using Xcode's built-in formatting
# Usage: ./Scripts/format_code_xcode.sh
# 
# This script opens each Swift file in Xcode and applies formatting
# Note: This requires Xcode to be installed and may open many files

set -e  # Exit on any error

echo "🔧 Formatting all Swift code files using Xcode's built-in formatting..."

# Find all Swift files in the project
SWIFT_FILES=$(find . -name "*.swift" -not -path "./build/*" -not -path "./.build/*" -not -path "./DerivedData/*")

if [ -z "$SWIFT_FILES" ]; then
    echo "❌ No Swift files found to format"
    exit 1
fi

echo "📁 Found $(echo "$SWIFT_FILES" | wc -l | tr -d ' ') Swift files to format"

# Find Xcode application
XCODE_APP=""
if [ -d "/Applications/Xcode.app" ]; then
    XCODE_APP="/Applications/Xcode.app"
elif [ -d "/Applications/Xcode-beta.app" ]; then
    XCODE_APP="/Applications/Xcode-beta.app"
else
    echo "❌ Xcode not found in standard locations"
    echo "Please ensure Xcode is installed in /Applications/"
    exit 1
fi

echo "✅ Found Xcode at: $XCODE_APP"

# Counter for formatted files
FORMATTED_COUNT=0
ERROR_COUNT=0

# Format each Swift file using Xcode
for file in $SWIFT_FILES; do
    echo "🔨 Formatting: $file"
    
    # Open file in Xcode and apply formatting
    # Note: This will open each file in Xcode
    if open -a "$XCODE_APP" "$file"; then
        echo "✅ Opened in Xcode: $file"
        echo "   Please use Editor > Structure > Format File (⌃⇧I) in Xcode"
        ((FORMATTED_COUNT++))
    else
        echo "❌ Failed to open in Xcode: $file"
        ((ERROR_COUNT++))
    fi
done

echo ""
echo "📊 Formatting Summary:"
echo "✅ Files opened in Xcode: $FORMATTED_COUNT"
echo "❌ Failed to open: $ERROR_COUNT files"
echo ""
echo "💡 To format all files:"
echo "1. In Xcode, use Editor > Structure > Format File (⌃⇧I)"
echo "2. Or use the main format_code.sh script if swift-format is installed"
echo ""
echo "🎉 Files are ready for formatting in Xcode!"
