---
name: reference-giants-i3d-exporter-blender
description: GIANTS I3D exporter (v10.5.0) install/enable for FS25 — works on Blender 5.1 despite the 3.6 minimum
metadata:
  type: reference
---

The FS25 I3D exporter is the file `io_export_i3d.zip` (from GDN / the game SDK). In Blender it
shows up as **"Project Motor Racing I3D Exporter Tools" v10.5.0** (maintainer: GIANTS Software &
Straight4 Studios — same I3D format across GIANTS games incl. FS25). Bundled tools include the DDS
converter, material/shape panels, motion-path/vehicle-array/vertex-color/splines tools.

**Install/enable (Blender's own "Add-ons" UI; GIANTS calls it a "plugin"):**
`Edit → Preferences → Add-ons → Install…` → pick `io_export_i3d.zip` (don't unzip first) → tick
**Project Motor Racing I3D Exporter Tools** (category: Game Engine). It installs to
`…\Blender\<ver>\scripts\addons\io_export_i3d\`. The GUI `.exe` installer
(`blender_i3d_export_10.5.0_win.exe`) does the same file-copy but auto-detects the Blender version;
the manual zip route is version-proof and produces an identical result. After enabling, the export
UI is a vertical tab **"PMR GIANTS I3D Exporter"** in the 3D-viewport N-panel (press N).

**Blender version — VERIFIED 2026-06-30:** the add-on's `bl_info` declares `"blender": (3, 6, 21)`,
which is a *minimum*, not a ceiling. GIANTS distributes/tests on Blender 3.6 LTS, but the exporter
**enables and registers cleanly on Blender 5.1.2** (tested headless: `addon_install` + `addon_enable`
succeed, export operator present; only a benign `SyntaxWarning: invalid escape sequence '\w'`). So do
NOT reflexively downgrade to 3.6. The one thing still unverified is a *full model export* on 5.x
(mesh/material API drift) — if a real export throws, THEN fall back to Blender 3.6 LTS
(archive: download.blender.org/release/Blender3.6/, latest 3.6.23). Relevant to [[reference-no-child-models]]
(custom Blender modeling is the only path for kid models / bespoke assets).
