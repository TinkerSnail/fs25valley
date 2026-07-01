---
name: feedback-repack
description: "Always run ./repack.sh after any code edit to the mod, without being asked"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: faaa0e39-d931-4477-a4f2-5a8ee0b14972
---

**Now ENFORCED by a hook** — a PostToolUse hook in `.claude/settings.json` runs `./repack.sh`
automatically on every `.lua` Edit/Write. The repack happens whether or not the model remembers.
See [[process-failsafes]]. The guidance below is the intent that hook enforces.

After every `.lua` edit to the mod, `./repack.sh` runs from the project root immediately.

**Why:** The mod runs from a zip in the FS25 mods folder; edited source files have no effect until repacked. There were multiple incidents (2026-06-20) of either not repacking or claiming a repack that did not actually run — which corrupted visual test feedback because the user loaded stale code. The hook exists specifically to make that failure impossible.

**How to apply:** The hook handles it. Never claim "repacking now" as a manual step; if you ever run it manually, show the actual Bash output, never a bare claim.

**After repacking, always tell the user:** "Fully quit FS25 and relaunch it to load the new code — reloading the save is not enough." FS25 reads the mod ZIP only at game launch, not on mission reload.
