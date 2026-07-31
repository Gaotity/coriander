# 16 — Layouts + settings bridge

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 08 (done), 22
**Status:** ready-for-agent

## What to build

Extends the native-style portrait layout system (ticket 22) to iPhone landscape, iPad full-size and floating-keyboard presentations; plus the App Group user-defaults bridge that carries UI-layer settings from the Container App to the keyboard.

## Acceptance criteria

- [ ] iPhone landscape adapts the ticket 22 layout system without disturbing portrait
- [ ] iPad full + floating presentations adapt
- [ ] A defaults value set in the app is read by the keyboard
- [ ] No layout regressions on compact sizes
