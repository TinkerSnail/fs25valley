# FS25Valley — Session Protocol

## REQUIRED: Before touching any code

Every session, before reading any Lua files or making any changes:

1. Read `/Users/christina/.claude/projects/-Users-christina-Dropbox-Mac-Documents-FS25Valley/memory/MEMORY.md`
2. Read any memory files that are relevant to the current task
3. Run `mcp__ccd_session_mgmt__list_sessions` and read the JSONL transcripts for any sessions relevant to the task (files at `~/.claude/projects/-Users-christina-Dropbox-Mac-Documents-FS25Valley/<cliSessionId>.jsonl`)

Do not skip this even if the task seems simple. The whole value of the working relationship is cumulative knowledge. Starting cold and rediscovering things that are already in memory is a failure mode that has cost many hours.

## REQUIRED: After any significant finding

Write it to the appropriate memory file immediately — not at the end of the session, not "later." If the context compacts before you write it, it's lost.

## Always repack after any .lua edit

Run `./repack.sh` from the project root without being asked. Every time.

## Never guess

Every change must be grounded in a confirmed finding from this session or a prior session. If the basis for a change is unclear, read the session history before proceeding.
