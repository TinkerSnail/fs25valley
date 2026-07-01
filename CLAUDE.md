# FS25Valley — Session Protocol

## REQUIRED: Before touching any code

Every session, before reading any Lua files or making any changes:

1. Read `journals/README.md` (the index), then read every `journals/*.md` file relevant to the task. These are the distilled engine knowledge and OFTEN ALREADY CONTAIN THE ANSWER. For anything touching NPC walking/animation, `journals/npc-movement.md` and `journals/lifecycle-and-hooks.md` are mandatory.
2. Read `memory/MEMORY.md` (the in-repo memory index; syncs across machines via git), then read any `memory/*.md` files relevant to the task. For NPC walking/animation work, `memory/walter_walker_history.md` (the R-table attempt log) is almost always relevant.
3. Run `mcp__ccd_session_mgmt__list_sessions` and read the JSONL transcripts for any sessions relevant to the task. (Transcripts are stored per-machine under `~/.claude/projects/…` and do NOT sync via git — they will only cover sessions run on the current machine.)

Do not skip this even if the task seems simple. The whole value of the working relationship is cumulative knowledge. Starting cold and rediscovering things that are already in the journals or memory is a failure mode that has cost many hours — most recently the Walter walk fix (2026-06-21), which was documented in `journals/npc-movement.md` and `journals/lifecycle-and-hooks.md` the entire time but went unread across ~17 attempts.

## REQUIRED: After any significant finding

Write it to the appropriate `memory/` or `journals/` file immediately — not at the end of the session, not "later." If the context compacts before you write it, it's lost. (Rule of thumb: distilled engine knowledge → `journals/`; project facts, process/QA notes, and the R-table → `memory/`. If nothing fits, create a new file and add it to that folder's index — `memory/MEMORY.md` or `journals/README.md`.)

## Always repack after any .lua edit

Run `./repack.sh` from the project root without being asked. Every time.

## Never guess

Every change must be grounded in a confirmed finding from this session or a prior session. If the basis for a change is unclear, read the session history before proceeding.

## Cross-platform (Mac + Windows)

This repo is developed on both a Mac and a Windows machine and synced via GitHub. Keep it
machine-agnostic — no per-switch edits should ever be required.

- **Open the project at the repo root** (the `fs25valley/` folder that contains `.claude/`).
  The hooks only fire when Claude Code is launched with this folder as the project root.
- **Build:** run `./repack.sh` (bash). It auto-detects the OS — zips directly on macOS, and
  delegates to `repack.ps1` on Windows. Both write `FS25_ValleyLife.zip` into the correct
  per-OS mods folder:
  - macOS: `~/Library/Application Support/FarmingSimulator2025/mods/`
  - Windows: `~/Documents/My Games/FarmingSimulator2025/mods/`
- **Memory and journals live in the repo** (`memory/`, `journals/`) so knowledge travels with
  git. Neither ships in the mod zip (both are excluded by the build).
- **Hook scripts are OS-portable** via `.claude/hooks/_common.sh` (paths, `stat`, `date`).
  They require `jq` on PATH (macOS: usually present / `brew install jq`; Windows:
  `winget install jqlang.jq`).
- **Not synced by git** (inherently per-machine): the game install + savegames + `log.txt`,
  Claude Code session transcripts, and the gitignored `.claude/.session-start` / `.preflight`
  markers and `settings.local.json`.
