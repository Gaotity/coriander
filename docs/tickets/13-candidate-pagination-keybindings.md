# 13 — Candidate pagination + schema keybindings

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 08
**Status:** ready-for-agent

## What to build

Page through Candidates beyond the first page (swipe or page control), and honor schema-defined keybindings (e.g. space commits the first Candidate) so typing matches desktop Rime habits. Also render Candidate comments in the candidate bar (spec user story 4) — deferred from ticket 08, whose bar shows text only.

## Acceptance criteria

- [ ] Candidates page 2+ reachable
- [ ] Space/number keys behave per the active schema's keybindings
- [ ] Pagination state resets on new Composition
