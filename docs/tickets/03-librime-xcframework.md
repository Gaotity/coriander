# 03 — Build librime core and assemble XCFramework

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 02
**Status:** ready-for-agent

## What to build

Compile librime itself against the ticket-02 dependencies and assemble the XCFramework(s) consumable from both app targets, including headers and a Swift bridging path. Collect third-party license files alongside.

## Acceptance criteria

- [ ] XCFramework builds for all three slices
- [ ] Headers/bridging consumable from Swift
- [ ] Third-party license files collected
- [ ] Build reproducible from clean checkout
