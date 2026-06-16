# Valley Life — Journals

Reference notes captured during development so we don't have to re-derive game
internals (style configs, palettes, API quirks) every time.

## Index

- [outfits-and-schedule.md](outfits-and-schedule.md) — **work/leisure rules**,
  holidays, seasons, birthdays, per-villager assignment matrix, baking checklist.
- [character-appearance.md](character-appearance.md) — character style configs
  (face/hair/beard/clothing), the `vlStyle` dump, palettes, and per-villager
  appearance item indices.
- [console-commands.md](console-commands.md) — all `vl*` dev console commands,
  **outfit testing loop**, and clothing-layer command tables.
- [dialog-boxes.md](dialog-boxes.md) — bottom-screen narration popup and reply
  selector: `drawFilledRectRound`, layout constants, input handling, and what
  *not* to do (PNG 9-slice corners).
- [dumps/](dumps/) — raw captured output from in-game diagnostic commands.

## Conventions

- Current mod version: **0.1.0.37** (check `modDesc.xml` / log line
  `Valley Life 0.1.0.37 loaded`).
- When a diagnostic command (e.g. `vlStyle`, `vlHairColors`) produces output we
  want to keep, paste the raw log block into `journals/dumps/` with a dated
  filename, and summarize the takeaway in the relevant topic file.
- Record *decisions* (e.g. "Kenji uses face 8") alongside the raw data so the
  reasoning is preserved.
- **Bake outfits** in `src/NPCSystem.lua`; console tweaks are live-only. Repack
  with `./repack.sh` → full FS25 relaunch.

## Villagers

| id | name | birthday |
|---|---|---|
| `elara` | Elara | February 10 |
| `kenji` | Kenji | May 8 |
| `marta` | Marta | November 5 |
