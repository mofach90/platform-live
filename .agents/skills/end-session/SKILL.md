---
name: end-session
description: Use at the end of every work session, or when the user says "wrap up", "end session", "handoff" or is about to switch to another AI tool. Updates docs/STATUS.md and docs/journal.md so the next agent can continue.
---

# End session

1. Run `make check` and note the result (pass / which step fails).
2. Update `docs/STATUS.md`:
   - **Last updated**: date, time, which agent (Claude Code / Codex).
   - **Done**: move finished items here with the commit or PR reference.
   - **In progress**: exactly where you stopped, which file, what is half-done.
   - **Next**: the next 1–3 concrete steps, small enough for one session.
   - **Blocked / open questions**: anything waiting on the human
     (e.g. "run bootstrap apply", "grant role X", "decide Y").
3. If anything failed during the session and was solved or is still open,
   add or update an entry in `docs/journal.md`.
4. If a design decision was made, make sure an ADR exists in `docs/decisions/`.
5. Show the user the diff of STATUS.md and suggest a commit message
   (`docs: update status`). Do not push.
