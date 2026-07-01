---
name: process-failsafes
description: "Hooks in .claude/ that enforce project process mechanically (repack, session-start context, R-table updates, stale-build detection)"
metadata:
  node_type: memory
  type: project
  originSessionId: ca8380d2-ce9f-46de-9065-56bc5b987e75
---

Installed 2026-06-21 after repeated process failures (not repacking and claiming to, letting
the R-table drift, analyzing stale builds). These run in the harness, NOT through model
discretion, so the process holds even when the model would otherwise skip it.

Files live in the project: `.claude/settings.json` + `.claude/hooks/`.

## What each one does

- **Auto-repack** (`settings.json` PostToolUse, matcher Edit|Write|MultiEdit): on any `.lua`
  file edit, runs `./repack.sh`. The repack can no longer be claimed without happening.

- **Session-start context + JOURNALS** (`settings.json` SessionStart → `inject-context.sh`): injects
  the journals (README index + npc-movement + lifecycle-and-hooks + development-process) AND memory
  (MEMORY.md, walter_walker_history.md, feedback_session_start.md) into context every session.
  Journals first — they're the distilled engine knowledge and usually already hold the answer (the
  Walter fix lived there unread). Also drops `.claude/.session-start` for the preflight gate.

- **Preflight gate** (`settings.json` PreToolUse → `preflight-gate.sh`): BLOCKS the first `*.lua`
  edit of a session until a fresh `.claude/.preflight` note exists (newer than `.session-start`).
  Forces reading the relevant journals/memory and checking whether a sibling feature already does
  this — written down — BEFORE coding. The step that would have prevented the whole Walter ordeal.

- **Verified log reader** (`.claude/hooks/read-walter-log.sh [pattern] [n]`): the ONLY way to read
  the live log. Runs the freshness check first and refuses to print on a stale build. Use this
  instead of grepping `log.txt` directly, so stale-log analysis becomes impossible.

- **R-table gate** (`settings.json` PreToolUse → `gate-table-update.sh`): BLOCKS (exit 2) any
  edit to `WalterWalker.lua` if FS25 has LOADED/TESTED a build more recently than the last update
  to `walter_walker_history.md`. I.e. once you relaunch and test a build, you must record that
  attempt's result before editing code again. Trigger = mod-load time in live `log.txt` (NOT the
  code file's mtime). An "attempt" = one tested build; each R# row summarizes the code changes AND
  the user-reported visual outcome. (Redesigned 2026-06-21 — see below.)

- **Stale-build verifier** (`.claude/hooks/verify-build.sh`): run FIRST whenever the user says
  "check". Compares the newest FS25 log's mod-load timestamp against the packed zip's mtime.
  Prints FRESH (safe to analyze) or STALE (tell user to relaunch). Prevents analyzing a build
  the running session never loaded — the single most repeated failure of 2026-06-20.

## Operating the R-table gate (REDESIGNED 2026-06-21 — test-triggered)

The gate triggers on TESTING, not on editing. It blocks a `WalterWalker.lua` edit iff FS25's
mod-load time (from live `log.txt`) is NEWER than `walter_walker_history.md`'s mtime — i.e. you
tested a build and haven't recorded its result yet.

- **Multiple edits per attempt: ALLOWED.** Assemble one build in as many edits as you want; the
  gate stays quiet because no new launch has happened. (The earlier mtime-vs-code design nagged
  between edits of one build — R12/R15 on 2026-06-21. That gotcha is GONE.)
- **After you relaunch and TEST a build:** the mod-load time jumps past the table, so the next
  code edit is BLOCKED until you record that attempt's R# row — a summary of the code changes AND
  the user-reported visual outcome. Then edits are allowed again.
- Each R# = one whole tested attempt, not a single edit.
- Do NOT bypass the gate. Recording the tested result before the next build is the entire point.

Why mod-load time works: FS25 writes a fresh `log.txt` per launch, so its
`Load mod: FS25_ValleyLife` timestamp = when the current build was tested. Same signal as
`verify-build.sh`.

## Note

On a fresh session, Claude Code may prompt the user to trust the project hooks. Approve them.
The R-table gate intentionally makes WalterWalker.lua edits fail until the table is current —
that is the feature, not a bug. See [[walter-walker-history]].
