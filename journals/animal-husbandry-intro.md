# Base-game animal husbandry — the full introduction flow (reference)

How FS25 onboards a player into animal husbandry on Riverbend Springs, mapped end-to-end (2026-06-25) so
we can decide what to extend without re-deriving it. **Two parallel systems** teach the same material: an
**NPC-conversational** path (Walter → Katie) and a **static help-line menu**. Full source text lives in
`~/fs25_npc_dialogue/npc/{grandpa,animalDealer}/` and `~/fs25_l10n/l10n_en.xml` (grep there for verbatim).
Characters: [[project-katie-character]], [[project-walter-story]], [[project-david-character]].

---

## Path A — NPC conversational (the on-brand one for us)

### Tier 1: Walter = the REFERRAL (`grandpa/help/animalHusbandry/`)
Ask grandpa about animal husbandry; he doesn't teach it — he vouches for the specialist and points you on:
- *"Talk to Katie, our local animal farmer. Very nice person, competent, charismatic."*
- *"She can tell you about different kinds of livestock. She's a trader, too, if you think about starting
  animal husbandry."*
- Branch options: **"Where can I find her?"**, **"What else can you tell me about her?"** → he adds the
  chipper / smart / well-traveled / "talking to David all the time" characterization. (Back / Exit.)

### Tier 2: Katie = the EXPERT TUTORIAL + TRADER (`animalDealer/help/animals/`)
**Entry** (`ahelpIntros`): *"Asking about animals. You found the right person! Where do you have issues?"*
→ opens the **overview menu** of 10 topics:

> **Cows · Chickens · Pigs · Sheep · Goats · Horses · Beekeeping · Waterbuffaloes · Silage and TMR** (+ Back/Exit)

**Per-species shape is consistent** — each species folder has an `Overview` (the sub-menu) + these leaves:
`howDoIFeed…`, `howDoIKeep…`, `whatEquipment…`, usually `breeds`. Variants: horses add **howDoISell**;
chicken adds **differenceChickenRooster**; beekeeping adds **whereDoI**; silageAndTMR = **whatIsSilage** +
**whatIsTMR**. (All 10 species' full text is in the dump; cows below is the exemplar.)

**COW branch, verbatim (the teaching content):**
- *Overview menu:* breeds / how to feed / how to keep / what equipment (Back/Exit).
- *differentBreeds:* "Brown-Swiss and Holstein are **dairy** cows. Angus and Limousin **don't produce
  milk — only for breeding/selling**. At 18 months they start producing milk / reproducing."
- *howDoIFeedCows:* "grass, hay or TMR… don't only feed hay or grass… **best results with TMR**… if you
  rely on milk, especially winter, prepare enough quality food."
- *howDoIKeepCows:* "need a **pasture or a barn**… **deliver fresh water** to a pasture (no built-in
  water)… **shape the outdoor enclosure** after placing… **slurry/manure needs at least a barn**."
- *whatEquipmentDoINeedCows:* tractor + **front loader + bale spike** (deliver bales), **manure heap**
  (if straw → manure), **forage mixer wagon** (mix TMR), **liquid manure tank** (slurry), spreaders +
  tanks to field, **milk/water transport tank**, and "cows on your field hurt your yield — use a pen."

Katie is ALSO the **trader** — you buy animals from her (`animals_dealer` = "Animal Dealer").

---

## Path B — static HELP-LINE menu (`helpLine_Animals_*`, the in-game Help panel)

Mirrors Katie's content in menu form (always available, no NPC needed):
- **Animals → How to care for your animals** → *Feeding*, *Selling animals and products*.
- **Per species:** Cows, Chickens, Pigs, Sheep, Goats, Horses, Bees, Water Buffalo, **Dog**.
- **General:** *General* ("if you want a break from harvesting… take care of animals: horses, cows,
  sheep, pigs, chickens"), *Buying animals*, *Housing animals*, *How to get manure?*, *Reproduction*.
- **Total Mixed Ration (TMR):** its own section — "**the only way to gain 100% productivity**"; *Get the
  ingredients*; *mixer wagon* (add straw/hay/silage/mineral feed in the shown ratio) **vs** *feeding
  robot* (deliver ingredients, it mixes + feeds automatically).

---

## The mechanics the tutorial points at (`animals_*` / `info_husbandry*` l10n)

- **Buying:** at the pasture/barn → delivered for a small fee, OR drive a **trailer to the dealership** and
  haul them yourself. ("not enough money" / capacity checks.)
- **Water/straw:** "Animals always need water! Barns have built-in water supply. Some animals also require
  straw." (chickens need a clean feeding area; horses need brushing/riding/cleanliness.)
- **Pens:** place a husbandry (pasture/barn), **shape the fence/pasture**; "pen capacity reached" / "you
  don't have a pen for this animal type."
- **Feeding:** food types have **effectiveness + quantity**; "mix for best results"; TMR = 100% for cows.
- **Manure/slurry:** straw in barn → **manure** (needs a **manure heap**); **slurry** → **liquid manure
  tank**; spreaders to fields. ("No manure heap nearby" / "No liquid manure tank nearby.")
- **Reproduction:** health-gated (kept healthy + fed → they reproduce; pen needs space).

---

## Entry points (how the player REACHES the intro)

1. Talk to **Walter** → ask about animal husbandry → referred to Katie.
2. Talk to **Katie** → her `help/animals` menu (also where you trade).
3. Open the **Help menu** → Animals (the static help-line).
4. Buy/approach a **husbandry placeable** → its own UI + `animals_description*` blurbs.

## Why this matters for us
The **Walter → Katie referral** we wanted to build is already the base-game structure (grandpa vouches,
specialist teaches + sells). It's voiced, on-brand, and tied to the starting **Angus** herd (beef, not
dairy — note the breeds line). Decision deferred (user: map first); options were wrap-a-narrative / extend
Katie additively / improve it. See the cake-romance and player-as-bridge threads
([[reference-basegame-npc-roster]], [[project-david-character]]).
