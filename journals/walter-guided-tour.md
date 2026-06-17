# Walter's guided tour - structure & injection seam

How the base-game intro tour works, why Walter's dialog can't be edited, and the
exact moment Valley Life can add a "go meet the town" beat after it.

**Relevant probe command:** `vlGuidedTour` (in `main.lua`, `VLConsole`).
**Hook targets (confirmed):** `GuidedTour.finish`, `GuidedTour.cancel`.

---

## Why Walter's lines are sealed

Walter (internal id **`GRANDPA`**) is a base-game NPC. His conversation files
live at paths like:

```
$dataS2/npc/grandpa/guidedTours/introUS/finished/conversation.xml
```

`$dataS2` resolves to **`dataS2.gar`** - a packed binary archive next to the game
binary. **Mods cannot read, replace, or inject into `.gar` files.** There is no
FS25 mechanism for a non-map mod to override content inside it.

The map-side `guidedTour_intro.xml` (in
`data/maps/mapUS/guidedTour/`) *is* readable, but contains **no dialog text** -
only references to `.gar`-internal conversation paths. So editing Walter's actual
words is **not possible** from a Valley Life-style mod.

What *is* possible: the `GuidedTour` **Lua class** runs in the same interpreter as
mods and is hookable with `Utils.appendedFunction`, same pattern as our mission
hooks. We can't change what Walter says, but we can fire our own dialog the
instant his tour ends.

---

## The tour is 100% mechanical

`guidedTour_intro.xml` is ~60 steps, **every one about operating equipment**:
cultivate field 4 → attach seeder → choose canola → seed → hire a helper →
switch to combine → harvest field 2 → unfold pipe → unload to trailer → drive to
the **grain elevator** → sell. There is **no social or town content** anywhere in
the tour. Walter is purely a farming instructor, and the economy he teaches ends
at the **grain elevator** - never the Farmer's Market.

---

## Walter's closing speech (reconstructed from voice-line filenames)

The tour ends with a real Walter conversation (`finished/conversation.xml`). We
can't open the `.bin` voice files, but the game logs each one as it loads, and
the filenames spell out the speech in order (captured 2026-06-16, savegame2):

```
youAreBack → wondering → paper → hereYouAre → seenImportantSteps →
moreToDo → specialEquipment → gainingFeel → leaveYouToIt → grandpa →
hereForYou → askBen → trustedHelpers → explainFarmingTechniques →
nowGetFarming → dungHeap → doJustFine → yourFarmNow
```

Reconstructed: *"You're back. Wondering what's next? Here's the paper - the farm's
in your name now. You've seen the important steps, but there's more to do…
special equipment, you'll gain a feel for it. I'll leave you to it. I'm here for
you - but ask **Ben**, he and the trusted helpers can explain farming techniques.
Now get farming. …the dung heap. You'll do just fine. It's your farm now."*

**The vanilla gap, confirmed:** his farewell names only **Ben** and "trusted
helpers." No town, no market, no Marta. It ends on "ask Ben" / "your farm now."

---

## The injection seam

**`askBen` is the one social referral in the entire tour.** A Valley Life line
extends the exact beat the base game opens and then drops - e.g.
*"…ask Ben for field help. And while you're finding your feet, there's Marta -
she runs the market in town. Worth a visit."* This continues `askBen` rather than
talking over Walter.

**Timing (pinned from the same log):** the final line `yourFarmNow_en.bin` loaded
at `18:31:29`; the post-tour autosave fired at `18:31:45`. So `GuidedTour.finish`
fires in that ~16-second window - right after "your farm now," before the player
has done anything. That's exactly where our bottom-panel box would appear:

```
Walter (native UI): "…it's your farm now."  →  native UI closes
       →  GuidedTour.finish fires  →  VL bottom-panel box opens with the market line
```

`GuidedTour.cancel` is the parallel hook for **skip-tour** players - the ones most
likely to wander into the empty market with zero context, since they miss the
whole mechanical wrap-up *and* the `askBen` beat.

---

## GuidedTour class surface (from `vlGuidedTour`, 2026-06-16)

```
cancel, class, cleanup, copy, delete, draw, finish, getCanAbort, getNPCSpot,
getPassedStepsInfo, isa, load, loadFromXMLFile, loadSteps, new,
registerSavegameXMLPaths, saveToXMLFile, setShowProgress, start, startStep,
superClass, update
```

- `g_currentMission.guidedTour` is the **live instance** - present only **while
  the tour is active**; it is `nil` once the tour finishes/cancels or on a save
  that never ran the tour. Hook the **class** (`GuidedTour.finish`), not the
  instance.

---

## Design reasoning - should we add a Walter beat at all?

The useful question isn't "XML or Lua?" - it's **what moment in the player's
first hours teaches them the market exists, and who owns that beat.**

### The vanilla state on day one

- The tour teaches **sell at the grain elevator**, not the Farmer's Market.
- Walter's farewell names **Ben** and "trusted helpers" - nobody else (see
  reconstructed speech above).
- The market is walkable, empty, full of non-interactive ambience NPCs -
  intriguing but unexplained.
- **Marta** (our mod) already closes the loop when found: her `firstMeet` names
  the market, the empty shelves, and the player's supplier role in one breath.

### Three teaching beats (think *when*, not *how*)

| Beat | Vanilla today | What we might add |
|------|---------------|-------------------|
| **1. Orientation** | "friendly neighbors…" | Name the town / market |
| **2. Economy** | tour → grain elevator | "you can also sell produce in town" |
| **3. Relationship** | nothing until you find Marta | Marta explains empty crates |

Marta's `firstMeet` already covers **Beat 3** well. The real question is whether
we need a Walter beat for **Beat 1** at all, or whether Beat 3 (discovery) is
enough.

### Option A - edit Walter's native dialog → NOT POSSIBLE

Would make Marta feel canon-adjacent from minute one. But Walter's lines live in
`dataS2.gar` and **cannot be edited by a mod** (see top of this file). Ruled out
on technical grounds, not design ones.

### Option B - Lua inject after the tour → the viable path

Treat Walter as vanilla, Valley Life as the social layer. Hook
`GuidedTour.finish` / `cancel` and open our own bottom-panel line right after his
farewell. Pros: pick the timing (tour-end is the seam), reference Marta + save
flags, one hook to maintain. Con: always slightly *adjacent* to vanilla (a second
box after Walter's UI closes) - mitigated by writing it as a continuation of
`askBen`.

### Lean recommendation (current thinking, not yet built)

- **Don't rush a Walter beat** unless playtesting shows people never find the
  market or it reads as broken rather than intriguing.
- The **real gap is discoverability** (does the player ever walk into the
  building?), which words alone don't fix - a **map marker / signage** for the
  market may matter more than a Walter line.
- If we add a line, **tour-finish (`GuidedTour.finish`) extending `askBen`** is
  the strongest spot - better timing than first-hello, less intro bloat.
- Keep Marta's `firstMeet` flat for now ("look who wandered in" = discovery
  fiction). Add a *"Walter said you'd come"* variant **only if** we set the flag
  and playtesting shows players expect a referral.

### Questions that decide it faster than the tech

1. Should day-one Walter be **longer or shorter**? (Intro is already a wall of
   text + a multi-hour tour.)
2. Is the empty market a **mystery or a problem**? Mystery → delay naming Marta.
   Problem → point there at tour-end.
3. Should Marta's first line **assume Walter sent you**? Yes → needs a Walter
   beat + flag. No → `firstMeet` stands alone.
4. Is **Marta at the market from save start**, or only after we place her? If not
   present day one, "go see Marta" is awkward.
5. Do **skip-tour** players get the same info? `finish` misses them - that's what
   `cancel` is for.

---

## Open implementation questions (not yet decided)

1. **Speaker attribution** for the injected line: label it `Walter` (needs
   NPCDialog to accept a plain-string speaker), leave it blank (narrator aside),
   or skip Walter entirely and let **Marta** be the first voice in free play.
2. **Save flag** (`walterMentionedMarket`) so the line fires once and can later
   gate a Marta `firstMeet` variant (*"Walter said you'd come"* vs *"look who
   wandered in"*).

This ties into the callback chain in [Marta.lua](../src/content/Marta.lua)
(`firstMeet` → acquaintance lines reference Walter).
