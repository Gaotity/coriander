# 04 — Link smoke test

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 03
**Status:** ready-for-agent

## What to build

Thinnest possible smoke: an app target links the XCFramework, prints the librime version on screen, and creates/destroys a Rime session without crashing, on both simulator and device.

## Acceptance criteria

- [ ] App shows librime version on simulator and device
- [ ] Session create/destroy runs clean
- [ ] No linker/arch warnings unresolved
