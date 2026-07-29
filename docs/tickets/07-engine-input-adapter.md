# 07 — Engine input-path adapter + minimal seed + first XCTest

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 04, 06
**Status:** done

## What to build

The project's deep module, atomic slice: a Swift Engine interface exposing only the input path — session lifecycle, key events, read Composition/Candidates, Commit. Nothing speculative: no Deploy or schema methods yet (added by the tickets that first need them). First-launch seed copies baseline data into the Rime Directory behind a blocking indicator (no progress UI). Establish the single test seam: XCTest drives the Engine against the seeded real data — type 'nihao', assert '你好' appears in Candidates.

## Acceptance criteria

- [x] Engine interface exposes only the input-path slice
- [x] Seed is idempotent (second launch skips)
- [x] XCTest at the seam: keys in, real Candidates out — green
- [x] librime types never leak past the interface

## Results

- `src/Engine/Engine.swift` is the deep module's input-path face: `Key`/`Candidate`/`InputState` value types, `startSession`/`endSession`, `processKey`, `input`, `selectCandidate`, `takeCommit`, `shutdown`. No librime type appears in any signature. One Engine per process is enforced with a static guard because librime cannot finalize and re-initialize within a process; the Container App therefore Deploys then shuts its Engine down, releasing the User Dictionary for the keyboard.
- Deploy at start is an `init(directory:deploy:)` flag, not a method — the Container App passes `true` on first launch, the Keyboard Extension will pass `false` (ticket 08). The full Deploy pipeline (progress, last-good preservation) stays with ticket 09.
- `src/Engine/RimeDirectory.swift` owns the Rime Directory layout (`rime/shared` + `rime/user` under the App Group container) and the seed. Idempotency is a `.seeded` marker written only after a Deploy that verifiably produced compiled artifacts under `user/build` — `join_maintenance_thread()` reports no status, so a silently failing Deploy is detected by its missing output and re-runs on next launch instead of being masked as seeded. On the Deploy-failure path the Engine finalizes before throwing, releasing the User Dictionary lock.
- The Container App's first launch now runs seed + Deploy behind a full-screen blocking indicator (`RimeBootstrap`), second launch skips straight to ready. Ticket 04/05's ad-hoc harness in the app (`RimeSmoke`, `RimePrepare`) is retired — the XCTest seam supersedes the link smoke, and the real seed path supersedes the prepare action. The keyboard-side measurement harness (`RimeMeter`, `KeyboardViewController`) is untouched — the extension target does not compile the Engine yet; ticket 08 adds the sources and rewires the harness, and ticket 05's device run can still use it meanwhile.
- `CorianderEngineTests` is a hostless unit-test target (own scratch Rime Directory under the temp dir, no App Group, no entitlements), wired into the `Coriander` scheme's test action. One Engine per test process is made real by `TestEngine.shared` (a `Result<Engine, Error>` held for the process lifetime, never finalized) — later Engine test classes call it rather than bootstrap their own.
- `Key.modifiers` stays a raw `Int32` mask for now: it has no consumer yet, and a typed `OptionSet` lands with the ticket that first needs modifiers (08/13).
- The seam test types 'nihao' against the seeded baseline, asserts '你好' is among the Candidates, selects it, and asserts the Commit equals '你好'. Green on the iPhone 17 Pro simulator (iOS 26.5).
