---
name: feedback_use_internet_for_observable_behavior
description: "Use WebSearch for observable/community-documented game behavior; don't infer from local files alone"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 211d3e5e-9ba5-4834-8c74-82189c2eb107
---

For questions about **observable in-game behavior** — especially what players SEE in multiplayer, or
anything whose ground truth lives in the sealed `dataS2.gar` (player/handtool controllers, IK, runtime
animation) — **use WebSearch/WebFetch**, don't infer from local files and present the inference as fact.

**Why:** On 2026-06-23 I claimed non-chainsaw handtools show "no body pose, just a swinging open hand."
Wrong. The spray can fully animates the arm to lift/point at the target (user confirmed via Gemini; it's
procedural IK, which the 87-clip dump can't see). I'd treated "no keyframed clip in the dump" as "no pose
at all." The user pushed back twice, then asked why I wasn't using the internet — a fair callout.

**Cost lesson (2026-06-23, said plainly by the user): community search is the CHEAP FIRST step, and
over-digging locally BURNS TOKENS for no reason.** The user surfaced the spray-can answer in <5 min with
one search. Don't grep transcripts / sweep game files / re-edit journals before doing the obvious lookup.
Order of operations for any "how does FS25 do X / what do players see" question:
1. **Community/official docs FIRST** — GDN (gdn.giants-software.com, character-animation threads), the
   FS wiki, forums, a quick web search. Cheap, fast, often definitive.
2. Base-game **console commands** exist for this stuff — e.g. `gsPlayerAnimationDebug`,
   `gsPlayerAnimationReload`. Point the user at them instead of deriving.
3. Local XML/Lua/schema only for engine internals not covered above.
Be economical: one good search beats ten greps. Stop when you have the answer.

**How to apply:**
- Local XML/Lua/schema is authoritative for engine *internals* (what the engine READS). Keep using it.
- But for what's OBSERVABLE/community-documented (MP appearance, gameplay feel, patch behavior), the
  forums/wiki/changelog/videos are the authority — the `.gar` logic isn't file-readable. Search the web.
- The clip dump lists only KEYFRAMED animations; it is blind to procedural IK. Never conclude "no pose"
  from "no clip."
- **The l10n KEY is not the rendered STRING.** 2026-06-25: the train sell-station label key is
  `station_us_trainOtherTown`; I inferred the destination was a "generic, unnamed other town." Wrong — it
  RENDERS in-game as **"Goldcrest Valley"** (user showed the ESC-map hotspot card). The user had said
  "Goldcrest Valley or something" and I second-guessed their memory against the key. Lesson: a label's
  meaning lives in the localized string (in `dataS.gar` l10n), not the key name; the on-screen text the
  player sees is authority. When the user recalls what a label says, trust it or check the rendered string
  — don't infer from the key.
- The project's "read the journals first / don't re-derive" protocol is about not re-discovering what we
  ALREADY wrote down — it is NOT a reason to avoid the internet. Both/and.

Related: [[feedback_rigor_over_speed]], [[feedback_why_we_circled]] — over-claiming an inference is the
same corrupted-observation failure mode. Hedge confidence; verify before asserting.
