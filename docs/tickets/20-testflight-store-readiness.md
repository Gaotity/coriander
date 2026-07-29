# 20 — TestFlight + App Store submission readiness

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 12, 13, 14, 15, 17, 18, 19
**Status:** ready-for-agent

## What to build

Ship-ready surface: app icon, screenshots and metadata, age rating, privacy nutrition labels that match actual behavior (no data collected, no network), and review notes per ADR-0003 (Full Access used solely for local writes). Upload a build to TestFlight and verify install on a clean device; external Beta App Review optional before closing.

## Acceptance criteria

- [ ] Build installs from TestFlight on a clean device
- [ ] Privacy labels match actual behavior
- [ ] Review notes state Full Access local-write purpose
- [ ] Icon/metadata/age rating complete
- [ ] Keyboard guidelines 4.4.1 checklist verified (globe key, works without Full Access)
