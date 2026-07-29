# 08 — Minimal keyboard input path (core tracer bullet)

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 07
**Status:** ready-for-agent

## What to build

The end-to-end tracer bullet: the Engine runs read-only inside the Keyboard Extension — keystrokes produce an inline Composition, a candidate bar shows Candidates, and selection commits into the host app. Includes the globe (next-keyboard) key required by App Store guideline 4.4.1.

## Acceptance criteria

- [ ] Type real text in any app (device or simulator)
- [ ] Composition renders inline; candidate bar selectable
- [ ] Commit inserts text into the host app
- [ ] Globe key cycles keyboards
