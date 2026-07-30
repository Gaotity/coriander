# 17 — Settings (schema list + UI preferences)

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 10, 16
**Status:** ready-for-agent

## What to build

Rime-layer settings: enable/disable and order schemas — writes default.custom.yaml in the Config Folder and triggers a Deploy. UI-layer settings: Layout choice and keyboard feel, propagated via the settings bridge. Note (from ticket 10): the Deploy failure detection (`Engine.failedSchemas()`) only scans the Rime Directory's `shared` side, so a broken schema arriving via the Config Folder compiles (and fails) silently — schema enable/disable makes this hole user-reachable and it must be refined here.

## Acceptance criteria

- [ ] Reorder/enable schemas in the app → Deploy → keyboard reflects
- [ ] UI-layer prefs reach the keyboard via the bridge
- [ ] Settings changes are reflected in the Config Folder (no shadow state)
