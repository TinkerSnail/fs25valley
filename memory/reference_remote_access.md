---
name: reference_remote_access
description: How to reach the Windows dev PC (SFF) remotely from the Mac — Tailscale IP, RDP, and SSH.
metadata:
  type: reference
---

The Windows dev machine is named **`SFF`** (Windows 11 Pro, local user **`Mike`**). It is set up
for remote work from the user's Mac. Configured 2026-06-30.

## Addresses
- **Tailscale IP: `100.68.130.116`** (device `sff`, tailnet account `christinamday@`). Works on
  both LAN and internet — prefer this address always.
- LAN IP: `10.0.0.173` (Wi-Fi; may change — Tailscale IP is stable).

## Access methods (both enabled on SFF)
- **RDP (full desktop):** Remote Desktop enabled with NLA, firewall open (port 3389). From the
  Mac use the **Windows App** (Mac App Store) → connect to the Tailscale IP as user `Mike`.
- **SSH (terminal / Claude Code / repack):** OpenSSH Server **confirmed working** after the
  2026-06-30 reboot — `sshd` Running + Automatic, listening on port 22, default shell PowerShell.
  From the Mac: `ssh Mike@100.68.130.116`. (It needed one reboot to finalize from `InstallPending`;
  a one-time `ClaudeFinishSSH` startup task handled that and self-removed.)
- **Sunshine + Moonlight (GPU-accelerated streaming — for GIANTS Editor / FS25 / any 3D app):**
  Sunshine host installed on SFF 2026-06-30 (`LizardByte.Sunshine`, `SunshineService` Running +
  Automatic). Encoder = NVENC on the **RTX 2070 SUPER**. Web UI config: `https://localhost:47990`
  (self-signed cert warning is expected — proceed anyway; you set a Sunshine-specific admin
  user/pass on first run, separate from the Windows login). Client = **Moonlight** on the Mac
  (`brew install --cask moonlight`), connect to `100.68.130.116` (works LAN + Tailscale), pair via
  PIN (Moonlight shows PIN → enter in Sunshine web UI "PIN" tab). Launch the **Desktop** app to
  stream the whole desktop for GIANTS Editor. Prefer HEVC/H.265 in Moonlight.

## GameStream conflict (with Sunshine) — how to actually disable it
NVIDIA GameStream uses the SAME ports as Sunshine (47984/47989 held by `nvcontainer`; 48010).
GeForce Experience 3.27 had GameStream enabled — a boot-race conflict with Sunshine.
**IMPORTANT LESSON (2026-06-30):** setting the registry flag
`HKLM:\SOFTWARE\NVIDIA Corporation\NvStream\EnableStreaming = 0` was **NOT sufficient** on its
own — `NvContainerLocalSystem` had already been running since boot and kept grabbing 47984/47989
whenever Sunshine wasn't holding them (proven by stopping Sunshine and watching nvcontainer
re-bind the ports). The authoritative off-switch is the **GeForce Experience UI**:
Settings (gear) → **SHIELD** tab → toggle **GAMESTREAM off**, then **reboot** (so NvContainer
starts clean and Sunshine binds the ports first). To VERIFY it's truly off: stop
`SunshineService` and confirm nothing `nv*` grabs 47984/47989 — if a port stays free with
Sunshine down, GameStream is genuinely disabled.

**RESOLVED 2026-06-30:** did GFE toggle + reboot. Confirmed clean — ports 47984/47989/48010 held
by `sunshine` only, no `nvcontainer` competing. First real Moonlight session from the Mac worked:
`hevc_nvenc` (H.265 on NVENC), 60fps, 10-bit YUV444. Streaming is verified end-to-end.

## Gotchas
- The Mac also needs **Tailscale** installed and logged in with the same account for the
  `100.x` address to route.
- RDP/SSH **reject a blank password** — the `Mike` account must have a real Windows password
  (the password behind any PIN/Hello, not the PIN itself).
- Sleep/hibernate disabled on AC power so SFF stays reachable; don't power the PC fully off when
  leaving.
