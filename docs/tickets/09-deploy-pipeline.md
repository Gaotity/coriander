# 09 — Deploy pipeline in the Container App

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 07
**Status:** ready-for-agent

## What to build

Container App Deploy action with progress and error reporting; last-good artifacts preserved on failure. The Engine gains its deploy interface here (first need). Seam tests assert: a new Session loads the new artifacts, and a failed Deploy leaves typing intact.

## Acceptance criteria

- [ ] Deploy runs with visible progress and clear errors
- [ ] Failed Deploy preserves last-good artifacts
- [ ] Seam test: new Session loads new artifacts
- [ ] Seam test: failed Deploy keeps typing intact
