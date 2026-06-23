# Bottom-screen dialog boxes

How Valley Life draws its narration popup and reply selector at the bottom of
the screen - the approach that actually worked in FS25.

**Implementation:** `src/gui/NPCDialog.lua`  
**Draw hook:** `main.lua` → `FSBaseMission.draw` → `g_valleyLife.dialog:draw()`

> **PRINCIPLE — mod dialog is ADDITIVE; never override or erase base-game dialog.** Do not suppress,
> replace, or block any base-game conversation/interaction (e.g. Walter/GRANDPA's "press to talk").
> Mod lines layer on top — Walter's time-of-day greetings are an **ambient popup on approach** while
> his base conversation stays fully reachable. Preserving base-game content is a standing rule.

---

## Why we roll our own

The base game has a bottom-center conversation UI (Walter/Ben tips use
`HUDPopupMessage`), but that widget is not exposed to mods in a way we can
reuse for multi-step heart events with custom choice layout.

Mod-callable alternatives:

| API | Problem |
|-----|---------|
| `YesNoDialog` / `MultiOptionDialog` | Centred modal - covers the villager's face |
| `HUDPopupMessage:showMessage` | Good for one line + continue, but truncates long text and has no inline choice list |
| GUI XML (`RoundCornerElement`) | Lives in the menu/GUI system, not the on-foot mission draw pass |

We need the whole conversation at the **bottom** of the screen, with word wrap,
a speaker line, continue hints, and a reply list with arrow-key navigation.
So we draw it ourselves each frame from the mission draw hook.

---

## Architecture (two panels, one draw pass)

```
Heart event step
       │
       ├─ plain line ──► showSpeechBox()  ──► drawSpeech() each frame
       │                      │
       │                      └─ Enter / click ──► next step
       │
       └─ choices ──► showSpeechBox (optional line first)
                           │
                           └─ nextFrame() ──► showReplySelector()
                                                  │
                                                  └─ draw() → panel + pills
                                                     Up/Down + Enter
```

**Speech box** - black rounded panel, wrapped body text, continue hint row
(`Enter` / mouse glyphs via `InputGlyphElement`). The speaker is rendered **inline**
(`Speaker: text…`) in one flow by default, matching the base game's tutorial
dialogue so every conversation feels cohesive. Pass `opts.inlineSpeaker = false`
to `showSpeechBox` for the older bold speaker-name header row instead.

**Reply selector** - same panel placement and width; optional question header
(often omitted when the line was already spoken); list of options; selected row
gets a lime capsule + ▶ marker; nav hint row (`↑↓` + `Enter`).

Both share layout constants (`SPEECH_BOX_W`, `SPEECH_BOX_BOTTOM`, padding, text
sizes) so narration and choices feel like one UI.

---

## Rendering: `drawFilledRectRound` (not PNGs)

### What works

```lua
-- cornerSize is in ENGINE units: 1.0 = 20px (RoundCornerElement docs)
local ENGINE_CORNER_PX = 20
local DIALOG_PANEL_CORNER_PX = 28

drawFilledRectRound(left, bottom, w, h, DIALOG_PANEL_CORNER_PX / 20, r, g, b, a)
```

- **Panel:** semi-transparent black `{0, 0, 0, 0.85}` with
  `DIALOG_PANEL_CORNER_PX` (currently **28px** radius).
- **Selected reply pill:** lime `{0.62, 0.80, 0.10, 0.92}`; set
  `REPLY_PILL_CORNER_PX = nil` for a full capsule (radius = half pill height).
- **Fallback:** if `drawFilledRectRound` is unavailable, `drawFilledRect` (sharp
  corners). If both are missing, fall back to native `HUDPopupMessage` / modal
  dialogs.

### What failed: PNG 9-slice corners

An early version used eight `Overlay` PNG tiles (`vl_panel_tl.png`, edges, fill,
pill caps, etc.). Corner pieces had thin opaque strips on their inner edges; when
scaled to ~18px slices they showed up as **four gray square brackets** in the
panel corners. Do not use this approach.

### Critical gotcha: corner radius units

`drawFilledRectRound(x, y, w, h, cornerSize, …)` takes **normalized** `x/y/w/h`
(0–1 screen space, bottom-left origin) but `cornerSize` is **not** normalized
the same way.

| Value passed | What you get |
|--------------|--------------|
| `0.026` (mistakenly treating 28px as screen fraction) | ~0.5px radius - looks square |
| `1.4` (`28 / 20`) | 28px radius - correct |

Always convert: `cornerSize = pixels / 20`.

---

## Assets

Only one texture is required:

| File | Purpose |
|------|---------|
| `gui/vl_tri.png` | ▶ marker on the selected reply (game font has no play glyph) |

Everything else is drawn with engine primitives.

---

## Layout & tuning knobs

All in the **Layout** / **Visual styling** block at the top of `NPCDialog.lua`.
Coordinates are normalized screen space unless noted.

| Constant | Role | Current |
|----------|------|---------|
| `SPEECH_BOX_W` | Panel width | `0.58` |
| `SPEECH_BOX_BOTTOM` | Distance from bottom edge | `0.052` |
| `SPEECH_PAD_*` | Inner padding | see file |
| `DIALOG_PANEL_CORNER_PX` | Panel corner radius (px) | `28` |
| `REPLY_PILL_CORNER_PX` | Pill radius; `nil` = capsule | `nil` |
| `REPLY_ROW_GAP_PX` | Space between choice rows (px) | `18` |
| `REPLY_PILL_PAD_X/Y` | Padding around selected label inside pill | `0.022` / `0.010` |

Row gap is pixel-based (`scaledScreenHeight(REPLY_ROW_GAP_PX)`) so the green
pill clears the unselected text below it on all resolutions.

Text is greedy word-wrapped via `getTextWidth` + `wrapText`, then the text
column is centred within the panel (left-aligned lines, centred block).

---

## Input

| Concern | Solution |
|---------|----------|
| Arrow keys walking the player | Dedicated input context `FS25_ValleyLife_REPLY` while selector is open (`setContext` / `revertContext`) |
| Custom Up/Down | Mod actions `VL_UP` / `VL_DOWN` in `modDesc.xml` (not stock `MENU_UP`/`MENU_DOWN` - those double-step) |
| Enter closing speech instantly picks a reply | `nextFrame(openSelector)` after speech dismiss |
| Continue on speech box | `MENU_ACCEPT` + `SKIP_MESSAGE_BOX` (mouse click) |
| Stuck movement after dialog | `restoreInputContextIfStuck()` + `VLNPCDialog:delete()` on unload |
| Mod update errors breaking game | `main.lua` wraps `g_valleyLife:update` in `pcall` |

Reply selector registers input only while open; speech box has its own event
set. Both tear down on `closeReply` / `closeSpeech`. Mission unload calls
`dialog:delete()` (not just `removeInput`).

---

## Integration points

- **Heart events:** `NPCEventSequencer` → `VLNPCDialog:showEventDialogue(step, sequencer)`
- **Casual talk:** `VLNPCDialog:openConversation(npc)` - heart events if ready;
  otherwise tier greeting (first meet / daily / already-talked) via `VLCasualDialogue`
- **Per-frame draw:** `FSBaseMission.draw` → `VLNPCDialog:draw()` (speech then reply)
- **Per-frame logic:** `FSBaseMission.update` → `VLNPCDialog:update()` (proximity
  prompt, stale reply cleanup, input context recovery)
- **While event active:** `update()` hides Press-R and skips proximity prompt;
  does **not** auto-close speech (event drives dialogue)
- **After event abort/reset:** `update()` closes stray reply selector; speech
  closes via its own callback or `abortActive()`

Full hook chain: [lifecycle-and-hooks.md](lifecycle-and-hooks.md).

---

## Testing

- `vlEvent <npcId>` - force-play the next heart event (see [console-commands.md](console-commands.md))
- `vlDlg` - probe which dialog APIs exist in the current build
- Repack `FS25_ValleyLife.zip` into the mods folder after changes; the game
  loads the zip, not the Dropbox folder directly

---

## Summary

1. Hook `FSBaseMission.draw` and paint each frame with normalized coords.
2. Use **`drawFilledRectRound`** for panel + pill; convert px → engine units (`÷ 20`).
3. Do **not** use PNG 9-slice for corners.
4. Keep one small PNG for the ▶ marker only.
5. Tune spacing and radius via the named constants at the top of `NPCDialog.lua`.
