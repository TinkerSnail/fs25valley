---
name: feedback_dialog_no_dashes
description: Custom NPC dialog must never use em/en/hyphen dashes as punctuation — use commas or semicolons
metadata:
  type: feedback
---

In all player-facing custom dialog, NEVER use a dash as punctuation: no em dash (—),
no en dash (–), and no spaced hyphen used as a dash (" - "). Replace with a comma or a
semicolon (semicolon when both sides are independent clauses; comma otherwise).

**Why:** The user dislikes dashes in the prose voice of the mod's dialogue (they read as
AI-tell / off-voice). Flagged 2026-07-01 after em dashes and spaced-hyphen dashes had
crept into several characters' lines.

**How to apply:**
- Scope is PLAYER-FACING dialogue strings only: `text = "..."` in
  `VLEventSequencer.registerEvent`, `label = "..."` choices, the `VLCasualDialogue.register`
  pools, and the `LINES` tables in WalterIntro/WalterCowsIntro. Do NOT touch code comments
  or `print()` debug strings (those still contain dashes and that's fine).
- PRESERVE compound-word hyphens (no surrounding spaces): `half-starved`, `burned-out`,
  `dirt-grubber`, `40s-50s`, `staying-in-Riverbend`. Those are not dashes-as-punctuation.
- Keep ellipses (`...`) and `*stage directions*` unchanged.
- Verify with: grep for `—`, `–`, ` - ` in `src/content/*.lua`; remaining hits should only
  be comment lines or Lua subtraction.

Related: [[project_npc_chooser_walter_talk]] (Marta), and the Marta market/sunflower rework
done in the same session.
