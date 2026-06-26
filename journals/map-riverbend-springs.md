# Riverbend Springs (mapUS) — the map we build on

The whole-map picture for Valley Life, so feature work (NPC schedules, heart-event staging,
economy tie-ins) starts from the real layout instead of guesses. **Riverbend Springs is the
FS25 US base map; in the game files it is `mapUS`** (`$DATA/maps/mapUS/`). Everything we've built
— Walter's routes, the woodshop, the guided-tour hooks — already lives on it.

> Method for going deeper (source paths, `.gar` extraction, the research playbook):
> [game-files-and-xml.md](game-files-and-xml.md). NPC definitions/dialogue:
> [character-systems.md](character-systems.md) + memory `reference-basegame-npc-roster` /
> `reference-npc-conversation-format`.

---

## Identity & scale

- `mapUS.xml`: **2048 × 2048**, manifest pointing at all the config below. US **riverine / midwest**
  theme — a river runs through it (barge terminals, dredging boat, fishing spots → hence *Riverbend*).
- **Environment** (`config/environment.xml`): `dayNightCycle=true`, `startHour=8`, **latitude 40.6**
  (drives seasonal daylight length), day window **dayStart 7 / dayEnd 19**. Latitude 40.6 ≈ US
  Corn Belt — meaningful seasonal swing, which our dusk-driven behaviors (e.g. Walter's flashlight)
  already key off.

## The named NPCs ARE the landowners

The base game's six NPC *types* live in `$data/maps/maps_npcs.xml` (see
`reference-basegame-npc-roster`). On Riverbend Springs, **five are physically placed** in `mapUS.i3d`
(`npcName` user-attributes): **GRANDPA (Walter), HELPER (Ben), FORESTER (Noah), ANIMAL_DEALER (Katie),
FARMER (David)**. FISHERMAN is *not* placed (fishing is the Highlands DLC system).

Crucially, the **93 farmlands** (`config/farmlands.xml`, `pricePerHa=60000`) are each tagged with an
`npcName` — i.e. every parcel is "owned" by one of these characters; buying land buys it from them.
- **GRANDPA owns the starting farm** (farmlands 1–5 `defaultFarmProperty="true"` + more) — the land
  Walter is literally handing the player. Direct mechanical backing for our Walter handoff fiction.
- Katie (ANIMAL_DEALER), David (FARMER), Noah (FORESTER), Ben (HELPER) own the surrounding parcels.

> Exact NPC stand positions: read at runtime (`g_npcManager:getNPCByName(NAME)` → `.x/.y/.z`, or
> `vlNpcDump`). The i3d only tags nodes; runtime is the reliable source.

## The starting farm (GRANDPA's) — what the player inherits

Preplaced cluster in `config/placeables.xml` (around **X≈-700, Z≈90–190, Y≈47**, from the guided-tour
`npcMove` coords). Tour-tagged buildings carry `tourId` (used by the intro):
- **farmHouse01** (with wardrobe) — the home; Walter's disappear/emerge door is here.
- **stable01** (`tourId="shed"`), **garage01** (`tourId="barn"`) — the tour's "shed"/"barn".
- **tinyShed01** — our **woodshop** (has `loadIndoorArea`; door `doorRotate02`, "Shed lights").
  See [walter-daily-life.md](walter-daily-life.md) §7 + [[walter-woodshop-door]].
- **cowBarnSmall** — preplaced with **3× `COW_ANGUS`** (age 50): *the cows that come with the base
  farm.* NOTE they're **Angus = beef/breeding, not dairy** (no milk). Katie's cow tutorial covers
  feeding-for-milk; the starting herd is beef — a real nuance if we write around "your cows."
- **beehives** (several `beehiveGeneric` + a pallet spawner) → honey; **farmSilo**, **farmGrainBinOld**,
  **windWheelMedium**, **objectStorage**, **dieselTanks01**, **farmerKioskSmall**, old barns.

## The wider economy + "the rest of the world"

162 placeables total. Beyond the farm:
- **Sell points — by their real in-game names** (`l10n_en.xml`, `station_us_*`): "Grain Barge Terminal
  01/02", "Grain River Silo", "Grain West Silo", "Grain Pool East", "Feed & Grain South", "Grain Mill",
  "Sawmill", "Spinnery", **"Red Marble Bowling Restaurant"** (the local restaurant is a bowling-alley
  diner), **"GrocerYmart"** (the grocery/mall, buys produce), "South Valley Biomass Energy"; plus
  water/manure buying. The grain infra is named by compass quarter (West/East/South) — implies a larger
  surrounding farm region.
- **Two channels OUT of the valley pull opposite ways** (the economy's thematic spine):
  - **River / barge terminals / grain silo** = the *raw* way out — bulk grain, cheap, value leaks
    downstream. The "sell it raw" pressure (debt-compatible if we ever build that).
  - **The train** = the *value-added* way out. You **rent** it (`trainSystem.xml`, 1000/hr), load it
    (grain/beet/woodchip/timber/flatbed wagons), and it sells at a **+15% premium** (`priceScale=1.15`)
    for the FINISHED categories (`SELLINGSTATION_PRODUCTS/_PRODUCTSFOOD/_WOOD`); raw seeds/wood are
    discounted. One spline, west↔east, **5 road crossings** — it physically threads the whole map.
- **THE RAILS GO TO GOLDCREST VALLEY** — confirmed VERBATIM from `l10n_en.xml`:
  `station_us_trainOtherTown` = **"Goldcrest Valley"** (the two train hotspots at map edges `1015 455` /
  `-1020 75`). So the wider world is canon: Riverbend Springs is wired by rail to **Goldcrest Valley** (the
  FS22 base valley) — a real sister farming valley our harvest goes to; the FS maps form a shared universe.
  (Per-map siblings: `station_as_trainOtherTown` = "Neighboring town", `station_fr_trainOtherTown` =
  "Marissonne" — each map's train points somewhere different; the US map's is named Goldcrest Valley.)
  Base NPC dialogue also names **Erlengrat** (the Alps = the German map `mapDE`, "Welcome to Erlengrat!")
  22× as the faraway getaway — a free near-world (Goldcrest) / far-world (Erlengrat) layer.
- **Map identity, verbatim:** `mapUS_title` = "Riverbend Springs", `mapUS_description` = "Welcome to
  Riverbend Springs!". The town is named on-screen and in NPC dialogue (36×).

> **Localization strings live at `~/fs25_l10n/l10n_en.xml`** (persisted 2026-06-25 from `dataS.gar`, ~12 MB
> text, all `station_us_*` / `mapUS_*` / UI keys). Grep it to resolve ANY in-game label — the rendered
> string, not the l10n key, is authority (see memory `feedback_use_internet_for_observable_behavior`).
> Re-extract via `fs-unpack dataS.gar` if it's ever missing.
- **Production chains** (each its own placeable + map icon): **dairy, bakery, sawmill, spinnery,
  ropemaker, tailor, oil plant, grain flour mill, paper mill, cooper, carpenter, cement factory,
  canned/packaged factory, BGA biogas, grain elevator museum, wagon builder, warehouse logistics,
  playground maker, dredging boat.** A full Western-farm value chain.
- **Shops:** vehicle trader, **animal trader (Katie's shop — `ANIMAL_DEALER_SHOP`)**, tailor, gas
  station, train station.

### Production recipes — the value web by input → output

Extracted from each `placeables/mapUS/<factory>/<factory>.xml` (`<production>` specs). This is the
mechanical interdependence the economy fiction rests on:

```
grain flour mill  WHEAT/BARLEY/OAT/SORGHUM -> FLOUR ;  RICE/RICELONGGRAIN -> RICEFLOUR
oil plant         SUNFLOWER->oil ; CANOLA->oil ; OLIVE->oil ; RICE->RICE_OIL
bakery            FLOUR -> BREAD ;  FLOUR + SUGAR + MILK_BOTTLED + EGG + BUTTER + STRAWBERRY -> CAKE
sawmill           WOOD -> BOARDS / PLANKS / WOODBEAM / PREFABWALL (+ WOODCHIPS)
carpenter         WOOD/BOARDS/PLANKS -> FURNITURE
cooper            PLANKS/BOARDS -> BARREL / BUCKET / BATHTUB (+ WOODCHIPS)
paper mill        WOOD -> PAPERROLL / CARTONROLL
spinnery          WOOL -> FABRIC ;  COTTON -> FABRIC
ropemaker         WOOL/COTTON -> ROPE
tailor            FABRIC -> CLOTHES
cement factory    STONE -> CEMENT / ROOFPLATES / CEMENTBRICKS
canning factory   CARROT/PARSNIP/BEETROOT/PEA/SPINACH/GREENBEAN -> preserved/canned ;
                  NAPACABBAGE+GARLIC+SPRING_ONION+CHILLI -> kimchi ;  FLOUR/RICEFLOUR + EGG -> NOODLESOUP
dairy             MILK -> dairy products (no <production> block in the placeable file — defined elsewhere)
```

**The cross-links that bind the cast** (a chain needs two owners' outputs):
- **CAKE** = David's `FLOUR` + Katie's `MILK_BOTTLED`/`EGG`/`BUTTER` → David + Katie collaborate.
- **CLOTHES** = Katie's `WOOL` → spinnery `FABRIC` → tailor.
- **FURNITURE / BARRELS** = Noah's `WOOD` → Walter's sawmill `BOARDS/PLANKS` → carpenter / cooper.

Shop (placement) names for the same factories, from l10n: Bakery, Dairy, Carpentry, Cement Factory,
Canning Factory, Cereal Factory, Biomass Heating Plant, Beehouse. (Design layer:
[../design/town-economy.md](../design/town-economy.md).)

## Ambient life, missions, collectibles (staging + flavor)

- **Setting = the American South, on a river (Arkansas).** In-world signage in `mapUS.i3d` names it:
  `signFerry02lastFerryInArkansas` ("last ferry in Arkansas"), plus `signFerry01DriveSlowOntoFerry`,
  `signWarningRisingWaterlevel`, `signRiverAccess` — a river-ferry, flood-prone river town. Latitude 40.6
  + cowboy-hat pedestrians + grain economy = US heartland/South. Town-texture signs also place a
  **school** (`signSchool01` ×2), a **general store** (`signTheGeneralStore`), a **company**
  (`signCompany01`), **fishing spots** (`signFishingSpot`), and a **"welcome home"** sign
  (`signWelcomeHome`) — concrete locations we can name and stage events at.
- **Pedestrians** (`config/pedestrianSystem.xml`): ambient walkers on `playerM/playerF` rigs,
  US small-town styling (cowboy hats), active **08:00–17:25**. Not named NPCs — pure background life.
  (Same rig family as our NPCs, per [[feedback-npc-can-do-what-player-can]].)
- **Contract missions** (`mapUS.xml`): deadwood, tree-transport, destructible-rock spots.
- **Fishing spots** (`mapUS.xml <fishingSystem>`): trout, e.g. `-460 -600` and `402 408`.
- **Collectibles** (`config/collectibles.xml`): **26** hidden antiques on a **grain-elevator-museum**
  theme (typewriter, telephone, steam engine, threshing machine, oil lamp, grain scoops…); achievement
  `CollectiblesUS`. A **footballField** easter-egg area also ships (`config/footballField.xml`).

## What this unlocks for us

- **Walter handoff has mechanical roots** — GRANDPA literally owns the default farmlands; the inheritance
  isn't just fiction. Worth weaving in.
- **Katie tie-in is grounded** — she owns animal parcels, runs `ANIMAL_DEALER_SHOP`, and already delivers
  a full voiced cow tutorial; the starting Angus herd gives a concrete reason to send the player to her.
- **Heart-event staging options:** the river/restaurant/town, the woodshop, the farm porch — all real,
  located places we can move NPCs to (NPCs walk the same rig the player does).
- **The other landowners** (Ben/Noah/David) are placed + conversational → the lighter villager cast can
  be these base NPCs, same hookable surface as Walter (to be confirmed live with `vlNpcDump`).
