# 07 — Engine input-path adapter + minimal seed + first XCTest

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 04, 06
**Status:** ready-for-agent

## What to build

The project's deep module, atomic slice: a Swift Engine interface exposing only the input path — session lifecycle, key events, read Composition/Candidates, Commit. Nothing speculative: no Deploy or schema methods yet (added by the tickets that first need them). First-launch seed copies baseline data into the Rime Directory behind a blocking indicator (no progress UI). Establish the single test seam: XCTest drives the Engine against the seeded real data — type 'nihao', assert '你好' appears in Candidates.

## Acceptance criteria

- [ ] Engine interface exposes only the input-path slice
- [ ] Seed is idempotent (second launch skips)
- [ ] XCTest at the seam: keys in, real Candidates out — green
- [ ] librime types never leak past the interface
