# 08 — Minimal keyboard input path (core tracer bullet)

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 07
**Status:** done

## What to build

The end-to-end tracer bullet: the Engine runs read-only inside the Keyboard Extension — keystrokes produce an inline Composition, a candidate bar shows Candidates, and selection commits into the host app. Includes the globe (next-keyboard) key required by App Store guideline 4.4.1. The extension target gains `src/Engine` sources here, and ticket 05's measurement harness inside it is retired onto the Engine + `RimeDirectory` (including `RimeMeter`'s duplicated path constants).

## Acceptance criteria

- [x] Type real text in any app (device or simulator)
- [x] Composition renders inline; candidate bar selectable
- [x] Commit inserts text into the host app
- [x] Globe key cycles keyboards

## Results

- The keyboard is a pure forwarder over the Engine. Every key goes through `processKey`; Commits are drained with `takeCommit` after candidate taps/space/return; `input` drives the inline Composition rendering and the candidate bar. Key semantics live in the Rime configuration, verified at the seam against the baseline defaults: space commits the first Candidate, Return commits raw input, Backspace shortens the Composition.
- `Engine.Key` gained its first named keys (`.space`/`.backspace`/`.return`, X11 keysym values) — the first non-letter consumers.
- `KeyboardEngine.shared` holds the extension's process-wide Engine as a `Result` — read-only, `deploy: false`; an unseeded Rime Directory shows a setup hint instead of the typing UI. One long-lived Session per extension process, per spec — `startSession` is guarded and effectively runs once. `Engine.clearComposition()` joins the interface now that a ticket first needs it: `viewWillAppear` drops any stale Composition, so text-field switches never inherit one.
- UI is programmatic and dark-mode-aware: candidate bar, three QWERTY rows, function row (globe / backspace / 空格 / return). The globe uses `handleInputModeList(from:with:)` (tap cycles keyboards, long-press shows the input-mode menu) per App Store guideline 4.4.1.
- Ticket 05's measurement harness is retired: `src/Shared/RimeMeter.swift` deleted (its path constants are now owned solely by `RimeDirectory`), `KeyboardViewController` rewritten onto the Engine, and `src/Engine` added to the extension's sources.
- Candidate bar shows text only; rendering Candidate comments (spec user story 4) is deferred to ticket 13.
- Unit: 5 seam tests green (candidates+commit, backspace, space, return, clear); full suite and the app+keyboard build green on the iPhone 17 Pro simulator. On-device typing smoke (iPhone 15 Pro Max / iOS 18.7.3, 2026-07-29, human run): inline Composition, candidate-tap commit, space-first-candidate, return-raw-input, backspace editing, globe cycling, and read-only typing with Full Access off — all confirmed working.
