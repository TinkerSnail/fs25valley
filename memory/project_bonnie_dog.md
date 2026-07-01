---
name: project-bonnie-dog
description: Bonnie — the farm dog the user added via the game UI; identity + how to find her at runtime
metadata: 
  node_type: memory
  type: project
  originSessionId: 33fa254f-a8a2-47e6-8dac-2639e02341ca
---

The user added a **dog named Bonnie** to the farm via the base-game UI (2026-06-28) and wants her baked into
the mod (role TBD — see below). She is a **doghouse placeable**, captured from the savegame `placeables.xml`:

- **Name:** Bonnie (`<doghouse name="Bonnie"/>`)
- **Placeable file:** `data/placeables/brandless/animalHusbandries/doghouse/doghouse.xml`
- **uniqueId:** `placeable38472a136110717a07d61f649fdd6f25`
- **Position:** x=-746.353 y=47.008 z=80.009, rotation y≈-20.21°, farmId 1, price 2500
- **Breed:** `<configuration name="dogHouse" id="8" isActive="true"/>` → the doghouse's **8th** `dogHouseConfiguration`
  = **Border Collie, Red & White** (spec `$dataS/character/animals/domesticated/dog/borderCollie/borderCollie.xml`).
  Configs 1–4 = Labrador (Black/Charcoal/Champagne/Chocolate), 5–8 = Border Collie (BlackTri/BlackWhiteMerle/
  BlackWhite/**RedWhite**=id 8). The doghouse.xml is LOOSE/readable; the dog character spec itself is sealed in dataS.gar.

**How to find her at runtime (to bake in):** mirror the truck (`vlFindWalterTruck` → `g_currentMission.vehicleSystem`
by uniqueId). For placeables it's the **placeable system** — find the doghouse placeable by `uniqueId`, then reach
the dog via the doghouse spec. The base-game **Dog scripts are sealed in dataS.gar** (not in the local decompiled
set, not found on disk) → extract with `fs-unpack`/`fs-luau-decompile` (the [[project-walter-truck]] toolchain) to
learn the runtime Dog API (follow/pet/fetch/ride-along, name, getDog…) before building behaviors. Game install:
`~/Library/Application Support/Steam/steamapps/common/Farming Simulator 25`.

**GOAL (clarified 2026-06-28):** the user does NOT care about follow/behavior — they want **Bonnie + her
doghouse present from the START of a NEW game** ("day one, moment one"). A fresh player's save won't have the
doghouse (it only lives in the user's own save), so the mod must **SPAWN the doghouse on new-game load**.
Design defaults agreed: spawn on a fresh game only IF missing (no duplicate); FREE (no 2500 charge); DON'T
re-spawn if the player later removes her (track a flag in the mod save, e.g. valleyLife.xml); Border Collie
Red/White (config id 8), named "Bonnie", at the captured pos, owned by the farm.

**SPAWN API — CONFIRMED via `vlDog` probe (2026-06-28):** both items spawn with the SAME LoadingData pattern as
the mod's flashlight loader (`HandToolLoadingData.new():setFilename(...):…:load(cb)`, main.lua:~805):
- **`PlaceableLoadingData`** (global, table): `:new()`, `:setFilename()`, `:setPosition()`, `:setRotation()`,
  `:setConfigurations()`, `:setConfigurationData()`, `:setOwnerFarmId()`, `:setIsRegistered()`, `:setIsSaved()`,
  `:load()` / `:loadPlaceable()`. Doghouse: configFileName `data/placeables/brandless/animalHusbandries/doghouse/
  doghouse.xml`, ownerFarmId 1, pos -746.35,47.01,80.01, config `dogHouse=8` (Border Collie RedWhite). Its dog
  spec on the placeable is `spec_doghouse` (lowercase).
- **`VehicleLoadingData`** (global, table): `:new()`, `:setFilename()`, `:setPosition()`, `:setRotation()`,
  `:setConfigurations()`, `:setOwnerFarmId()`, `:setIsSaved()`, `:load()` / `:loadVehicle()`. Truck configs:
  attacherJoint=1, baseColor=37, design=2, fillUnit=1, folding=1, motor=1, rimColor=38, tensionBelts=2, wheel=1.
- **"Already there?" checks:** `placeableSystem:getExistingPlaceableByXMLFilename(fname)` /
  `:getPlaceableByUniqueId(uid)`; vehicles → iterate `vehicleSystem.vehicles` by configFileName.

**WRINKLE:** a freshly-SPAWNED truck gets a NEW uniqueId ≠ the hardcoded `vehiclea0e08…` that `vlFindWalterTruck`
matches → must switch truck-finding to match by MODEL (series200 configFileName + farmId), or the market drive
can't find the spawned truck. **PLAN:** spawn-on-new-game-if-missing, FREE, once (flag in valleyLife.xml so
removal is respected). Tie-ins: [[project-walter-story]], [[project-walter-truck]].
