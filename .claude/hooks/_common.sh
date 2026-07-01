#!/bin/bash
# Shared cross-platform helpers for the FS25Valley hooks.
# Sourced by the other hook scripts so macOS (Darwin/BSD userland) and Windows
# (Git Bash / MINGW + GNU userland) behave identically with no per-machine edits.

# FS25 game-data dir (holds mods/, log.txt, savegameN/). Differs by OS.
fs25_base() {
  case "$(uname -s)" in
    Darwin) printf '%s' "$HOME/Library/Application Support/FarmingSimulator2025" ;;
    *)      printf '%s' "$HOME/Documents/My Games/FarmingSimulator2025" ;;  # Windows (Git Bash) / Linux
  esac
}

# File modification time as epoch seconds. GNU stat (Linux/MINGW) first, then BSD (macOS).
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

# "YYYY-MM-DD HH:MM:SS" -> epoch seconds. GNU date first, then BSD date.
to_epoch() { date -d "$1" +%s 2>/dev/null || date -j -f '%Y-%m-%d %H:%M:%S' "$1" +%s 2>/dev/null || echo 0; }

# A file's mtime as HH:MM:SS (display only). GNU date first, then BSD stat.
mtime_human() {
  date -d "@$(mtime "$1")" +%H:%M:%S 2>/dev/null || stat -f '%Sm' -t '%H:%M:%S' "$1" 2>/dev/null || echo '??:??:??'
}
