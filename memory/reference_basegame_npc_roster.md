---
name: reference-basegame-npc-roster
description: "FS25 base-game characterized town NPCs (Walter, Ben, David, Katie, Noah, Alasdair) — who teaches what; Katie = livestock"
metadata: 
  node_type: memory
  type: reference
  originSessionId: d300dc87-aa70-4230-899e-6879787ac90d
---

FS25 base game ships a small roster of **characterized, conversational town NPCs** (new in FS25 — talking
to them is optional). Confirmed via the FS Wiki NPCs page + farming-simulator.com NPC article
(2026-06-25). This matters because our mod's characters ARE some of these (Walter = GRANDPA), and the
base game already assigns onboarding/teaching roles we should build ON, not around.

| NPC | Base-game role |
|---|---|
| **Grandpa Walter** | Shares family-farm history; eases new players into farming. (= our [[project-walter-constraint]] GRANDPA — base game already frames him as the onboarding grandfather.) |
| **Helper Ben** | Farming basics: sowing, harvesting, machinery, improving crop yield. |
| **Neighbor David** | Beginner perspective; warns against common mistakes; city-vs-rural. |
| **Animal Farmer Katie** | **The livestock NPC.** Came home to take over the family animal farm; explains livestock-farming BASICS + travel anecdotes (admits some are myths; "not always serious"). |
| **Lumberjack Noah** | Forestry basics; discusses woodcarving + forest management. (Adjacent to Walter's woodshop arc.) |
| **Sailor Alasdair** | Deep-sea/ocean stories (Highlands Fishing Expansion only). |

**Re: the "cow-care tutorial" question** — there is NO structured step-by-step cow-care tutorial in the
base game. Katie is the closest: she talks livestock basics in CASUAL conversation (flavor + broad
guidance + anecdotes), not a how-to. Her actual lines are undocumented ("To be expanded" on the wiki).
So if we want real cow-care tutorial content, the lore-correct deliverer is **Katie**, by EXTENDING her
rather than bolting dialog onto the animal-dealer shop trigger (which is a menu, see
[[project-flashlight-beam-brightness]] note's sibling: the green-paw buy icon ≠ a character).

**Internal names (data/maps/maps_npcs.xml — loose/readable):** GRANDPA, FORESTER, FARMER, HELPER,
ANIMAL_DEALER, FISHERMAN. Each → `$dataS2/npc/<name>/<name>.xml` (sealed in dataS2.gar; not extracted
yet). **Katie = ANIMAL_DEALER.** Mapping (high confidence): GRANDPA=Walter, ANIMAL_DEALER=Katie,
HELPER=Ben, FORESTER=Noah(lumberjack); FARMER=David? / FISHERMAN=Alasdair (less certain).

**Hookability — STRUCTURALLY CONFIRMED (2026-06-25):** Katie/ANIMAL_DEALER sits in the SAME maps_npcs.xml
list, loaded by the SAME `g_npcManager` (npcs.xsd schema), same `$dataS2/npc/` layout as GRANDPA. We
already drive Walter via `g_npcManager:getNPCByName("GRANDPA")` (WalterWalker.lua:117) — so
`getNPCByName("ANIMAL_DEALER")` returns the same CLASS of entity. User's hypothesis (same principles as
Walter) holds at the manager level.

**CONFIRMED FROM FILES (2026-06-25, extracted dataS2.gar → animalDealer.xml):** Katie is structurally
the SAME NPC type as Walter — `playerStyle = dataS/character/playerF/playerF.xml` (FEMALE player rig),
`<filename>$dataS/character/npc/npcBase.i3d`, `<interactionTrigger node="triggerNode"/>`, and a
data-driven `<conversations>` list of `conversation.xml` files (each `uniqueId`-keyed). Same rig + same
conversation plumbing ⇒ her hook surface matches GRANDPA. Hypothesis CONFIRMED at the definition level.

`mapUS.xml` loads `maps_npcs.xml`, and `mapUS.i3d` PLACES her (`npcName="ANIMAL_DEALER"`,
`uniqueId="ANIMAL_DEALER_SHOP"`) ⇒ strong file evidence she's physically present on Riverbend Springs.
**Still wants RUNTIME confirmation** (only files were checked): is she spawned + `isActive` on RIVERBEND SPRINGS (mapUS)?
Use `vlNpcDump` (main.lua, near walterRig) — no-arg roster survey; `vlNpcDump katie` detail (aliases
walter/katie/ben/noah). If active+rig true, extend additively like Walter; if not spawned, VLNPCEntity path.

**KATIE — canon characterization, from WALTER'S OWN base dialogue** (durable `~/fs25_npc_dialogue/npc/
grandpa/help/animalHusbandry/` + `smalltalk/`, pulled 2026-06-25). Walter has a whole help branch that
HANDS THE PLAYER OFF to her — so our "Walter points to Katie" plan is EXTENDING CANON, not inventing:
- *"Talk to Katie, our local animal farmer. Very nice person, competent, charismatic."*
- *"She can tell you about different kinds of livestock. She's a trader, too, if you think about starting
  animal husbandry."* (the direct hand-off to her cow tutorial + ANIMAL_DEALER_SHOP)
- *"One smart woman. Hands-on mentality and not shy with the animals. Or the townsfolk."* / *"…very
  chipper, if you don't give her a reason to be anything else."* / *"Traveled a lot, learned farming in
  other countries, always got an anecdote."* / Walter finds her young-folk jokes hard to follow.
- **David↔Katie ROMANCE (canon, fully written, mutual slow-burn — 2026-06-25):** a ready-made arc.
  DAVID is smitten: always helping her (hauls her livestock to safety in a twister, bales her hay),
  *"glad to help Katie and her cows,"* cooks for her (*"Katie is coming over, I want to be a good host"*),
  asks the player *"what do you think of her, if I may ask?"*, and *"will definitely bake a cake for Katie
  to thank her."* KATIE warms back, fond+teasing: *"your dear and astoundingly courteous neighbor David,"*
  tea dates, *"Oh David, honey…,"* *"hanging out with David too much,"* warming to a fishing date while
  ribbing his klutziness (a piglet outsmarted him; his bales rolled downhill). **CONVERGENCE (real, with a caveat):**
  the bakery CAKE = flour + milk/eggs sits between the crop-farmer (David) + animal-farmer (Katie) domains,
  AND canon independently has David bake Katie a cake → a lovely thematic rhyme, prime first heart-event.
  CAVEAT (corrected 2026-06-25): canon does NOT say David makes/supplies the flour — the cake's flour is
  unattributed and nobody is tied to the grain mill. "David's flour" was an inference (David = the FARMER
  NPC), NOT a stated fact — do not assert it as canon. David IS a crop farmer (grain/soy/sunflower/potato),
  earnest but comically inept (wasted a harvest sleeping in, wrong combine header, bales downhill), a
  theory-heavy advice-giver. Katie also has a BROTHER in something
  "respectable" (sounds medical) — loose lore.
- **Ben (HELPER) & Noah (FORESTER), characterized by Walter:** BEN = *"a rather quiet fellow, has not
  very much to say except if you ask him about farming"*; *"my good old helper Ben, he'll explain the
  basics in detail"* (the tutorial farming-knowledge guy, reserved). NOAH = *"our local lumberjack… a
  kind soul, even though he seems a bit grumpy"* (gruff exterior, warm core). Tone anchors for building
  them — and Walter clearly knows/vouches for the whole town (he's the warm hub).
Walter's COW/animal voice (warm, folksy): *"nothin' sweeter than a newborn calf takin' its first steps,"*
*"cows befriend other cows in their herd,"* the petting-zoo cow, *"easy as spilling milk."* See
[[project-walter-story]] (Paul consulted Katie about his chickens — ties Paul ↔ Katie too).

**MAJOR — the cow-care tutorial the user asked about ALREADY EXISTS, voiced, via Katie.** Her
`help/animals/` tree has a full per-species branching tutorial: cows / chicken / pigs / sheep / goats /
horses / waterbuffaloes / beekeeping + silageAndTMR. The COWS branch = cowsOverview (menu) →
differentBreeds, howDoIFeedCows (grass/hay/TMR; "best results with TMR"; winter milk prep), howDoIKeepCows
(needs barn/pasture; slurry+manure need a barn; deliver water to pasture; outdoors), whatEquipmentDoINeed.
So we do NOT need to write a cow tutorial — base game has a thorough one. Strategic options instead: make
sure Katie is present on our map; and/or have Walter/Elara POINT to her; and/or extend her additively with
our flavor. See [[reference-npc-conversation-format]] for the conversation.xml/text architecture.

Extracted tree was in scratchpad (ephemeral). Re-extract with `~/fs25_tools/target/release/fs-unpack
"<Resources>/dataS2.gar" <out> -s` (~14s).

**CAST PRIORITY — build the NPCs Walter actually introduces (user direction 2026-06-25).** Frequency
Walter names each across all his dialogue: **Paul 152, Ben 74, Katie 51, Noah 20, David 20** (Paul =
[[project-walter-story]] great-uncle, off-map family lore, not a placed NPC). In the TUTORIAL/tour
specifically, Walter explicitly hands off to **Ben**: "If you want more detailed info, you can also ask
Ben" + "He has been one of my most trusted helpers," and nudges "your friendly neighbors you should talk
to some time." So build order, grounded: **Ben (HELPER) first** (the tour's named hand-off), then Katie
(done the research), then Noah/David. All are the same hookable NPC type as Walter ([[ — confirm live
with `vlNpcDump`). Each base NPC has the same conversation system ([[reference-npc-conversation-format]])
+ a full smalltalk/help tree we can extend additively or point to.
