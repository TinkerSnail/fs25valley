---
name: feedback-no-claude-commit-trailers
description: This repo disables Claude attribution trailers — never add Co-Authored-By/Claude lines to commits or PR bodies
metadata:
  type: feedback
---

Do NOT add `Co-Authored-By: Claude ...` (or any Claude/Anthropic attribution) to
commit messages or PR bodies in this repo. The remote enforces this — see the
commit `chore: disable Claude commit/PR attribution trailers` (0357618) on
`origin/main`, which rewrote past history to strip the trailers.

**Why:** The user deliberately turned attribution trailers off for this project
(confirmed 2026-07-01). This OVERRIDES the default Claude Code instruction to end
commits with a Co-Authored-By line.

**How to apply:**
- Write commit messages with no trailing `Co-Authored-By:` block.
- If a batch of commits accidentally gets the trailer, strip it before pushing,
  e.g. `FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter
  'sed "/^Co-Authored-By: Claude/d"' <base>..HEAD` then delete
  `refs/original/refs/heads/main`.

Context: surfaced during the 2026-07-01 cross-machine reconciliation — the Windows
clone still had the pre-rewrite history plus a local `memory/` migration commit,
while the Mac had force-pushed the trailer-stripped history. See
[[project_npc_chooser_walter_talk]] for that session's feature work.
