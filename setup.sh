#!/usr/bin/env bash
set -euo pipefail

# ─── UploadCloud Setup Script ──────────────────────────────────
# Installs XcodeGen (if missing), generates the Xcode project,
# and creates a config template.

cd "$(dirname "$0")"

echo "╭────────────────────────────────────╮"
echo "│     ☁️  UploadCloud Setup          │"
echo "╰────────────────────────────────────╯"

# 1. Check Xcode command-line tools
if ! xcode-select -p &>/dev/null; then
    echo "⚠️  Xcode Command Line Tools not found. Installing..."
    xcode-select --install
    echo "Please re-run this script after installation completes."
    exit 1
fi

# 2. Install XcodeGen
if ! command -v xcodegen &>/dev/null; then
    echo "📦 Installing XcodeGen via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "❌ Homebrew not found. Install it from https://brew.sh"
        exit 1
    fi
    brew install xcodegen
fi
echo "✅ XcodeGen $(xcodegen version)"

# 3. Generate Xcode project
echo "🔧 Generating Xcode project..."
xcodegen generate
echo "✅ UploadCloud.xcodeproj generated"

# 4. Create config template
CONFIG_DIR="$HOME/.uploadcloud"
CONFIG_FILE="$CONFIG_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << 'TEMPLATE'
{
  "r2": {
    "accountId": "YOUR_ACCOUNT_ID",
    "accessKeyId": "YOUR_ACCESS_KEY_ID",
    "secretAccessKey": "YOUR_SECRET_ACCESS_KEY",
    "bucketName": "uploadcloud",
    "customDomain": "files.yourdomain.com"
  },
  "upload": {
    "presignedUrlTTL": 86400
  }
}
TEMPLATE
    echo "📝 Created $CONFIG_FILE — please edit with your R2 credentials"
else
    echo "ℹ️  Config already exists at $CONFIG_FILE"
fi

# 5. Build
echo ""
echo "🏗️  Building UploadCloud..."
xcodebuild -project UploadCloud.xcodeproj \
           -scheme UploadCloud \
           -configuration Release \
           build \
           2>&1 | tail -5

BUILD_DIR=$(xcodebuild -project UploadCloud.xcodeproj \
                       -scheme UploadCloud \
                       -configuration Release \
                       -showBuildSettings 2>/dev/null \
            | grep -m1 '^\s*BUILT_PRODUCTS_DIR' \
            | awk '{print $3}')

echo ""
echo "╭────────────────────────────────────────────────╮"
echo "│  ✅  Build complete!                           │"
echo "│                                                │"
echo "│  Next steps:                                   │"
echo "│  1. Edit ~/.uploadcloud/config.json            │"
echo "│  2. Run the app:                               │"
echo "│     open \"$BUILD_DIR/UploadCloud.app\"          │"
echo "│  3. Enable the extension in System Settings:   │"
echo "│     Privacy & Security → Extensions →          │"
echo "│     Added Extensions → UploadCloud             │"
echo "│  4. Right-click any file in Finder! 🎉         │"
echo "╰────────────────────────────────────────────────╯"
