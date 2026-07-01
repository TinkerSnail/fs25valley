---
name: feedback-why-we-circled
description: "Post-mortem: why the Walter walk fix took ~17 attempts despite the answer being in our own prior Marta work"
metadata:
  node_type: memory
  type: feedback
  originSessionId: ca8380d2-ce9f-46de-9065-56bc5b987e75
---

The Walter walk solution (R17, 2026-06-21) was reachable far sooner — the answer was in our own
Marta work the whole time. Why we couldn't glean it at first, so we don't repeat the pattern:

1. **THE REAL #1 (corrected): the answer WAS in the journals, and I didn't read them.** Not a
   capture gap — a compliance failure. The R17 twitch fix is documented almost verbatim:
   - `journals/npc-movement.md:51-58` — "Walk animation: NPCs use direct-track animation… `gfx:update()`
     is skipped while either track is direct — the engine advances the tracks."
   - `journals/lifecycle-and-hooks.md:130` — "no `gfx:update()` needed in direct mode."
   - `journals/lifecycle-and-hooks.md:141-142` — "**Do not** call full `gfx:update()` on every NPC
     every frame" — which is exactly what g_npcManager does to Walter and exactly what R17 stops.
   `CLAUDE.md` explicitly says to ALWAYS read the journals before touching code. I didn't. The
   knowledge was distilled, usable, and indexed (README: npc-movement.md = "walk animation clips").
   The system worked; I bypassed it. (My earlier claim that this lived "only in raw transcripts" was
   FALSE — corrected 2026-06-21 after the user pointed it out.)
   FIX: actually read `journals/` (esp. npc-movement.md, lifecycle-and-hooks.md) at session start,
   not just memory + transcripts. The journals are the distilled engine knowledge; they often
   already contain the answer.

2. **A surface difference blocked the shared substrate.** Walter = base-game NPC (g_npcManager),
   Marta = our spawned entity — so I assumed Marta's code had nothing to teach. But both run the
   SAME GIANTS character/animation system; Marta's code held the literal fix. Lesson: "different
   control path" ≠ "different problem domain." Always check whether two features share the underlying
   engine system before assuming one can't inform the other.

3. **Corrupted observations made good experiments lie.** Reading the wrong log file
   (archived `logs/` instead of live `log.txt`) + unreliable repacking meant the R-table was partly
   built on builds that weren't running. That produced confident-but-FALSE "confirmed facts" (the
   R7/R8 C-side-writer theory) that sent us down dead ends. Unreliable ground truth → no convergence.
   FIX: the failsafes ([[process-failsafes]]) — verify-build, auto-repack, live-log reading.

4. **Re-proposed an already-rejected approach** (doppelganger) because that constraint wasn't in
   memory either. FIX: [[project-walter-constraint]] now records it.

THROUGH-LINE: cumulative knowledge only compounds if learnings are captured in a usable form AND
observations are trustworthy. Both were broken. The fix was not capability — it was process
discipline + correct framing (and splitting the monolithic "twitch" into facing vs animation-state).
Related: [[feedback-rigor-over-speed]], [[feedback-session-start]].
