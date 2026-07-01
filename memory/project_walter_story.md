---
name: project-walter-story
description: "Walter's characterization (settled, lives in Walter.lua header) + farm-debt plotline (liked, scope/TIMING pinned)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4307b9b7-fe94-4f9f-bd09-b06b6a152de2
---

Walter's character bible now lives in the header comment of `src/content/Walter.lua`
(house style: epithet + bio + four-beat arc, matching Marta/Elara/Kenji, whose bios
also live atop their `src/content/*.lua` files — that's where character story is captured,
not a separate doc). That header is the source of truth; this memory holds the lore +
the open decision so a future session doesn't re-derive or accidentally over-build it.

**Settled (2026-06-22):**
- Epithet: **"the one handing it on"** — present-tense handoff, deliberate counterpoint
  to Kenji ("can't let go"). The handoff is a PACT the player agreed to, not a past event.
- Role: the player's **WELCOME REPRIEVE** — warm and openly proud (canon: Marta's "lit up
  like a porch lamp", [[walter-daily-life]]). Teaches accountability to hard work + its
  rewards, and how to WEATHER hard times. Widowed; at peace with it. Warm with a dry edge,
  **NOT gruff** — the current placeholder casual lines tip a bit harsh and should be softened.
- Emotional spine: the 2–4pm woodshop hour = he's secretly **building the player a gift**,
  revealed over a four-beat arc (Earned Rest 20 / Weathering 40 / The Shed 60 / What I Made You 80).
- Family tree: player ← dad ← Walter. The **uncle** = dad's brother = Walter's OTHER son,
  who blew his original stake in the farm on something irresponsible → the debt.
- **BASE-GAME CANON: great-uncle Paul** (verbatim from durable dialogue `~/fs25_npc_dialogue/npc/grandpa/`;
  Walter names "Paul" 152× — the most of anyone). **CONFIRMED from Walter's own line:** Paul is *Walter's
  brother* → the player's GREAT-uncle, one generation ABOVE our invented debt-uncle (dad's brother =
  Walter's son), so they do NOT collide on the family tree. Paul is the lovable-knucklehead comic figure
  of the family. Verbatim:
  - *"My own brother did not really help either. He was too busy with his foolishness of a sugar beet
    stand in the middle of nowhere. Where he ONLY sold sugar beet, nothing else."* (`smalltalk/aboutGrandpa/
    grandpaFamily/familyHistory/sugarBeet_en.xml`)
  - *"…his silly sugar beet stand that flopped like a donkey's tail."* / *"your great uncle Paul, that old
    knucklehead."* / *"all the stupid questions that your uncle Paul always asks"* (the `metGrandmaPart2–5`
    arc — Paul is woven into HOW WALTER MET GRANDMA: a town-hall scene, a dumb question, they "laughed at
    uncle Paul" and shook hands).
  - *"your uncle Paul wanted to make a Bed & Breakfast out of it."* (`specialConversations/mapSpecific/
    riverbendCollectibles/bedAndBreakfast_en.xml`)
  - Gameplay tie-in: the sugar-beet harvest mission quips *"Please don't open a sugar beet stand, though.
    You're not your Uncle."* (`missions/field/harvesting/sugarBeet/…`)
  **Build WITH Paul** — he's free, beloved, canon family texture, the comic counterweight to the (pinned,
  darker) debt-uncle. **Tonal watch-out:** Paul = harmless failed-venture comedy; the debt-uncle = the
  recklessness that actually hurt the farm. Keep them DISTINCT so the family doesn't read as "two
  irresponsible uncles." Paul's sugar-beet stand also ties to the map economy
  ([[reference-basegame-npc-roster]]).
- **BASE-GAME Walter is a PROGRESS-gated proud witness, not a day-by-day tutor** (confirmed 2026-06-25,
  `~/fs25_npc_dialogue/npc/grandpa/conditionalDialogue/`). The guided tour is a ONE-TIME day-1 onboarding;
  there is NO "day 2" lesson. After it, his unique content unlocks on MILESTONES (not day count):
  ownedFields **3 / 10 / all**, **$1M** in bank, **1 month** played, **1 year** played — plus seasonal
  lines + the help referrals + missions + huge smalltalk. The milestone lines are EMOTIONAL BEATS that
  are dead-on our characterization: *"Your farm really is an empire now… I am so, so proud of you,"*
  *"$1M — that's all I ever wanted. Not the money; that's just an indicator."* So his arc is **day-1
  teacher → lifelong PROUD WITNESS**. KEY for us: his gating is PROGRESS-based, which COMPLEMENTS (doesn't
  compete with) our relationship-threshold heart events — we can add our own milestone-gated Walter beats
  (e.g. hang the woodshop-gift reveal on a progress/relationship milestone) in the same proud-grandfather
  register the base game already uses.

**Liked but PINNED — do NOT build yet:**
- The farm carries a debt; taking it on is part of why it passes to the player =
  "financial motivation / period of challenge." User likes the depth but flagged the full
  version (corporate/predatory lender, recurring uncle villain, cast-wide saga) as TOO
  COMPLICATED. Keep it a single backstory line for now.
- **TIMING is the open pin.** Options surfaced: (1) mid-game crisis tied to the Weathering
  beat [my rec], (2) opening stakes that loom from day one, (3) soft background goal,
  (4) slow burn into a mid-game crisis.
- Also undecided: where the player's **Dad** is (passed/estranged/absent), whether the
  uncle ever **resurfaces** as a face, and what the collateral/scheme actually was.

**Why:** User wants depth + financial motivation without complexity creep, and wants
Walter's voice right (warm, not harsh) *before* writing his real time-of-day lines — that
ordering avoids rework. **How to apply:** author Walter content against the Walter.lua
header; do not expand the debt into a plotline until the timing pin is resolved.
Related: [[project-walter-constraint]], [[walter-woodshop-door]], [[project-open-decisions]].
