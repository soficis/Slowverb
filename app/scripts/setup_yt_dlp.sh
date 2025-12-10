#!/usr/bin/env bash
#
# setup_yt_dlp.sh
# Downloads yt-dlp into a tools directory if not already present
#
# Usage (default tools dir next to this script):
#   ./setup_yt_dlp.sh
#
# Usage (custom tools dir):
#   ./setup_yt_dlp.sh /path/to/tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$SCRIPT_DIR/tools}"

echo "Target tools directory: $TARGET_DIR"

# Create directory if needed
if [ ! -d "$TARGET_DIR" ]; then
    echo "Creating tools directory..."
    mkdir -p "$TARGET_DIR"
fi

YT_DLP_PATH="$TARGET_DIR/yt-dlp"

# Check if already installed
if [ -f "$YT_DLP_PATH" ]; then
    echo "yt-dlp already present at:"
    echo "  $YT_DLP_PATH"
    exit 0
fi

# Official latest download URL
YT_DLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"

echo "Downloading yt-dlp from:"
echo "  $YT_DLP_URL"
echo ""

if command -v curl >/dev/null 2>&1; then
    curl -L "$YT_DLP_URL" -o "$YT_DLP_PATH"
elif command -v wget >/dev/null 2>&1; then
    wget "$YT_DLP_URL" -O "$YT_DLP_PATH"
else
    echo "Error: Neither curl nor wget found. Cannot download yt-dlp."
    exit 1
fi

# Make executable
chmod +x "$YT_DLP_PATH"

echo "yt-dlp downloaded to:"
echo "  $YT_DLP_PATH"

# Verify installation
echo ""
echo "Verifying yt-dlp..."
"$YT_DLP_PATH" --version

echo "Done."
exit 0
