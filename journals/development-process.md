# Development process & failsafes

Mechanical guardrails that enforce the session protocol, so it doesn't depend on the
assistant remembering. Configured in `.claude/settings.json` + `.claude/hooks/`.
(Full detail also in memory: `process_failsafes.md`.)

## The hooks

| Hook / script | When | What it does |
|------|------|--------------|
| Auto-repack | PostToolUse on any `.lua` Edit/Write | Runs `./repack.sh` automatically. The repack can't be skipped or falsely claimed. |
| Session context + journals | SessionStart → `inject-context.sh` | Injects the **journals** (README index + npc-movement + lifecycle-and-hooks + dev-process) AND memory into context every session. Also drops `.claude/.session-start` for the preflight gate. The answer is usually already in the journals — this puts them in the room. |
| **Preflight gate** | PreToolUse on any `*.lua` edit → `preflight-gate.sh` | BLOCKS the first code edit of a session until a fresh `.claude/.preflight` note exists (newer than `.session-start`). Forces: read the relevant journals/memory + check whether a sibling feature already does this, written down, BEFORE coding. |
| R-table gate | PreToolUse on `WalterWalker.lua` edits → `gate-table-update.sh` | BLOCKS the edit if FS25 has tested a build (mod-load in `log.txt`) more recently than the R-table was updated. |
| **Verified log reader** | manual: `.claude/hooks/read-walter-log.sh [pattern] [n]` | The ONLY way to read the log. Refuses to print unless the running build is FRESH. Makes stale-log analysis impossible. |
| Build verifier | manual: `.claude/hooks/verify-build.sh` | Freshness check (live `log.txt` mod-load vs packed zip). Used by the reader and the R-table gate. |

## Session preflight — required before any code edit

Every session, before editing mod `.lua`, the preflight gate forces you to:
1. Read `journals/README.md` + the journals relevant to the task (NPC/anim → `npc-movement.md` +
   `lifecycle-and-hooks.md`). They're auto-injected at session start, but READ them.
2. Read relevant memory, and check whether a **sibling feature already does this** (e.g.
   `NPCEntity`/Marta) — its code/journal often holds the answer.
3. Write `.claude/.preflight` recording: which journals/memory you read, the existing approach they
   describe, and why the new work differs.

This single step is the one that would have prevented the Walter ordeal (the fix was in the
journals the whole time). It gates only the FIRST code edit per session.

## R-table gate — how to operate it (don't fight it)

Test-triggered (redesigned 2026-06-21). It blocks editing `WalterWalker.lua` only if FS25 has
**loaded/tested** a build (mod-load timestamp in live `log.txt`) more recently than
`walter_walker_history.md` was updated. An "attempt" = one tested build, not one edit.

- **Assembling a build:** make as many code edits as you need — all allowed, because no new
  launch has happened. The old design that nagged between edits of one build is gone.
- **After you relaunch and test a build:** the next code edit is blocked until you record that
  attempt's R# row — **a summary of the code changes AND the visual outcome the user reported.**
- Each R# row covers a whole attempt. Never bypass or disable the gate; recording the tested
  result before the next build is the entire point.

## Which log to read (critical)

FS25 writes the LIVE log to `~/Library/Application Support/FarmingSimulator2025/log.txt` (parent
folder). It is renamed into `logs/log_<timestamp>.txt` only on exit. ALWAYS read `log.txt` for the
running session; the `logs/*.txt` files are closed/stale sessions. `verify-build.sh` reads `log.txt`.
