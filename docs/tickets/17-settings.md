# 17 — Settings (schema list + UI preferences)

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 10, 16
**Status:** ready-for-agent

## What to build

Rime-layer settings: enable/disable and order schemas — writes default.custom.yaml in the Config Folder and triggers a Deploy. UI-layer settings: Layout choice and keyboard feel, propagated via the settings bridge.

## Acceptance criteria

- [ ] Reorder/enable schemas in the app → Deploy → keyboard reflects
- [ ] UI-layer prefs reach the keyboard via the bridge
- [ ] Settings changes are reflected in the Config Folder (no shadow state)
