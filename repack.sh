#!/bin/bash
# FS25 loads mods from Application Support, NOT this Dropbox folder directly.
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/Library/Application Support/FarmingSimulator2025/mods/FS25_ValleyLife.zip"
cd "$PROJECT"
zip -r "$DEST" . \
  -x "*.git*" -x ".claude/*" -x ".cursor/*" -x "*.DS_Store" -x "journals/*" -x "docs/*" -x "*.zip" -x "repack.sh"
echo "Packed -> $DEST"
ls -la "$DEST"
