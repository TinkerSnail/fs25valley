#!/bin/bash
# Build FS25_ValleyLife.zip into the game's mods folder. FS25 loads mods from the game-data
# dir, NOT this repo folder. Cross-platform: on macOS this zips directly; on Windows (Git Bash)
# it delegates to repack.ps1 (Windows has no `zip`, and Compress-Archive needs special handling).
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
  Darwin)
    DEST="${HOME}/Library/Application Support/FarmingSimulator2025/mods/FS25_ValleyLife.zip"
    mkdir -p "$(dirname "$DEST")"
    rm -f "$DEST"
    cd "$PROJECT"
    zip -r "$DEST" . \
      -x "*.git*" -x ".claude/*" -x ".cursor/*" -x "*.DS_Store" \
      -x "journals/*" -x "docs/*" -x "memory/*" -x "*.zip" -x "repack.sh" -x "repack.ps1"
    echo "Packed -> $DEST"
    ls -la "$DEST"
    ;;
  *)
    # Windows (Git Bash / MINGW) or anywhere with PowerShell available.
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PROJECT/repack.ps1"
    ;;
esac
