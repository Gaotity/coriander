# 05 — librime inside the extension: real-device measurements

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 04
**Status:** ready-for-agent

## What to build

Temporary harness that initializes librime inside the Keyboard Extension on a real device: measure memory footprint with the baseline dictionary loaded, cold-start time, and probe the jetsam threshold (keyboard memory limits are undocumented; community consensus is ~30-60 MB with silent kills and no crash logs). This validates ADR-0001's premise. Record results here; harness on a throwaway branch.

## Acceptance criteria

- [ ] Extension memory footprint with loaded dictionary recorded
- [ ] Cold-start time recorded
- [ ] Jetsam behavior documented
- [ ] Go/no-go note on ADR-0001 details recorded
