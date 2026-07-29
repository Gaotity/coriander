# 15 — Export + User Dictionary management

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 14, 10
**Status:** ready-for-agent

## What to build

Export the User Dictionary (and other persistent state) as a single archive into Files-visible storage for backup/migration; clear the User Dictionary from the Container App, respecting the single-writer rule.

## Acceptance criteria

- [ ] Export archive lands in Files-visible storage
- [ ] Archive restores via the Import path (round-trip noted)
- [ ] Clear works without corrupting the keyboard
- [ ] Single-writer rule respected during management ops
