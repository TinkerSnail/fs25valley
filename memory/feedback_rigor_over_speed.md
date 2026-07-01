---
name: feedback-rigor-over-speed
description: "User strongly prefers slow, rigorous, evidence-grounded debugging over fast quick-fixes"
metadata:
  node_type: memory
  type: feedback
  originSessionId: ca8380d2-ce9f-46de-9065-56bc5b987e75
---

The user would rather wait a long time for a CORRECT, evidence-grounded answer than receive
quick turnaround guesses. Quick fixes that turn out wrong waste whole days and are far more
costly than slow rigor. Stated explicitly 2026-06-21 after a deep root-cause analysis of the
Walter rotation problem (finding the log.txt-vs-archived-logs bug, and self-correcting an
over-read conclusion).

**Why:** On this project a wrong conclusion gets written into permanent memory and a stale build
gets tested for hours. The expensive failure mode is confident-but-wrong, not slow. Depth,
showing the evidence chain, and catching your own over-reads are what the user values.

**How to apply:**
- Ground every claim in observed data from THIS session (live `log.txt`, exact values). No guessing — see CLAUDE.md "Never guess."
- Distinguish what the data actually proves from what it merely suggests. State caveats (e.g. "Lua reads happen before the render pass, so this can't see X").
- When a prior conclusion is contradicted by new data, correct the record immediately and say so plainly. Self-correction is valued, not penalized.
- Do NOT rush to ship a code change to look productive. A diagnostic that nails the mechanism beats three speculative fixes.
- Take the time. Long and correct > fast and wrong. Related: [[walter-walker-history]], [[feedback-session-start]].
