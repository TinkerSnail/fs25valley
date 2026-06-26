# Riverbend Springs — town economy & the wider world (design)

**Status: design-in-progress (worldbuilding).** The *facts* this rests on are in
[../journals/map-riverbend-springs.md](../journals/map-riverbend-springs.md) (map, recipes, the train
destination); this doc is the *fiction* we layer on them. Goal (user, 2026-06-25): give the map's
production chains a sense of purpose — tie the town together, tie it to its characters, and place it in
the context of a larger world.

---

## The premise (one line)

Riverbend Springs is a small Arkansas-river farming town deciding what kind of place it is: one that
ships itself out **raw and cheap**, or one that **builds what it grows** into something worth keeping —
and worth sending into the world with its name on it. **Walter is the patron saint of the second kind.**

## The spine: three ways out of the valley

Every channel out of Riverbend is real on the map, and they pull in different directions — this tension
is the economic story:

| Channel | What it is (grounded) | What it means |
|---|---|---|
| **The river** ("Grain Barge Terminal 01/02", "Grain River Silo") | bulk raw grain, cheap, fast | value *leaks* downstream. The "sell yourself short" temptation. Debt-compatible. |
| **The local table** ("Red Marble Bowling Restaurant", "GrocerYmart") | finished food sold in-town | value *kept*, but small. The modest, honest middle. |
| **The rails to Goldcrest Valley** (rent the train, +15% on finished/wood/food) | built-up goods railed to a real neighboring valley | value *grown and shared* — build it up here AND reach the world. The hero path. |

> All names are the real in-game sell points (`l10n_en.xml`). The grain infra is named by compass quarter
> — "Grain West Silo", "Grain Pool East", "Feed & Grain South", "South Valley Biomass Energy" — which
> quietly implies Riverbend sits inside a *larger agricultural region*, not alone. Good for the "context
> of a larger world" goal even before the rails leave the map.

The rails are the reconciliation: building it up and reaching the world aren't opposites. That **is**
Walter's creed ("what you build by hand outlasts you") turned into infrastructure.

## The wider world (named, canon)

- **Goldcrest Valley** — the named destination at both ends of the rail line (in-game hotspot label;
  the FS22 base valley). Riverbend's **peer / sister farming valley**, one ridge over, where the harvest
  actually goes. The wider world has a name and a face.
- **Erlengrat** — the Alps; the faraway "someday I'll get away" place the base NPCs already reference
  (22× in their smalltalk). The dream-world, not the trade-world.
- So the world has two rings already: **Goldcrest (near, peer, trade)** and **Erlengrat (far, dream)** —
  and the FS maps form a shared universe Riverbend sits inside.

## The value web → the cast owns it

The map's farmland is tagged by NPC owner, so each landowner already sits atop a branch of the
production web. Each villager becomes the **face of their chain** (narrative ownership, Stardew-style —
not a forced factory mechanic):

| Character | Land / role | Raw → their craft | Binds to |
|---|---|---|---|
| **Noah** (FORESTER) | the forest | timber, woodchips | feeds Walter's mills + the paper mill |
| **Walter** (GRANDPA) | the home farm; **woodcraft** | timber → boards/planks → **furniture, barrels** (sawmill, carpenter, cooper) | needs Noah's timber; his woodshop is the seed of the whole craft chain |
| **Katie** (ANIMAL_DEALER) | animals; runs the trader | milk → dairy; **wool → cloth** (spinnery → tailor) | her dairy feeds the bakery; her wool feeds the tailor |
| **David** (FARMER) | the crop fields | grain (→ flour, *design assoc.*); oil; preserves (cannery) | grows grain; bakes Katie a cake (canon) |
| **Ben** (HELPER) | the teacher | the grain/elevator + "how it works" | the broker for what leaves the valley |

**The chains literally bind the characters** (from the recipes):
- **Cake = flour + milk + eggs + butter** → it naturally sits between the two domains: flour from a crop
  (David is the crop farmer) and milk/eggs from animals (Katie's). **CAVEAT — don't overstate:** canon does
  NOT say David mills/supplies the flour; nobody is tied to the grain mill and the cake's flour is
  unattributed. "David's flour" is OUR design association, not a stated fact. What IS canon: David grows
  crops (incl. grain), and — independently — David (smitten) vows to *"bake a cake for Katie to thank her"*
  while she warms to him (*"Oh David, honey…"*). So the thematic rhyme is real and lovely (a cake bridges
  crop-farmer + animal-farmer, and the game already has him baking her one) — just not literally "his flour
  in her cake, per canon." Still a prime first heart-event. (Memory `reference-basegame-npc-roster`.)
- **Clothes = Katie's wool → the tailor.** **Barrels & furniture = Noah's timber → Walter's craft.**

## How it hooks our characters' arcs

- **Walter:** the rails-not-the-river choice IS his lesson. He's not anti-world — he's anti-selling-cheap.
  The train hauling *finished* goods to Goldcrest is him, vindicated.
- **The pinned farm-debt** ([[project-walter-story]]): the river is its pull — pressure to dump grain
  raw/cheap for fast cash. The uncle (Walter's other son) is the "easy money downstream" temptation made
  human. **Do NOT build the debt out yet — pinned;** just note the economy is shaped to receive it.
- **Katie:** the starting Angus herd + her `ANIMAL_DEALER_SHOP` + her existing voiced cow tutorial =
  grounded, lore-correct onboarding into the animal branch.

## Open / to decide (not settled)

- What does trading with **Goldcrest Valley** *mean*? Proud peer, quiet rival, or where someone left to?
- Which chain gets the **first heart event** with economic weight (Walter's woodshop-gift is the standout).
- Confirm **Ben/Noah/David** are live + hookable like Walter (`vlNpcDump`) before casting them as the
  lighter ensemble.
- How literal to make ownership (pure narrative vs. light mechanic). Default: narrative face-of-the-chain.
