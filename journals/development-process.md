# Development process & failsafes

Mechanical guardrails that enforce the session protocol, so it doesn't depend on the
assistant remembering. Configured in `.claude/settings.json` + `.claude/hooks/`.
(Full detail also in memory: `process_failsafes.md`.)

## The hooks

| Hook | When | What it does |
|------|------|--------------|
| Auto-repack | PostToolUse on any `.lua` Edit/Write | Runs `./repack.sh` automatically. The repack can't be skipped or falsely claimed. |
| Session context | SessionStart | Injects MEMORY.md + walter_walker_history.md + protocol into context (no cold starts). |
| R-table gate | PreToolUse on `WalterWalker.lua` edits | BLOCKS the edit if FS25 has tested a build (mod-load in `log.txt`) more recently than the R-table was updated. |
| Build verifier | manual: `.claude/hooks/verify-build.sh` | Run FIRST on "check". Compares live `log.txt` mod-load time vs packed zip. FRESH/STALE. |

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
