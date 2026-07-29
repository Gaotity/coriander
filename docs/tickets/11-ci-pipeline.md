# 11 — CI pipeline (quota-aware)

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 07
**Status:** ready-for-agent

## What to build

GitHub Actions macOS workflow that builds both targets and runs XCTest. Frugal by design: the repo is public so Actions is free, but keep it lean anyway — cache the XCFramework keyed by the pinned librime version (rebuild only when the pin changes), trigger only on code-path changes, skip docs-only changes.

## Acceptance criteria

- [ ] Workflow builds both targets and runs XCTest green on a PR
- [ ] XCFramework cache hit on the second run (no dep rebuild)
- [ ] Docs-only change does not trigger a build
