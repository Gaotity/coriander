# 01 — Platform validation spike + developer account decision

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** None — can start immediately.
**Status:** in-progress (agent half done; awaiting human device run)

## What to build

Minimal Container App + Keyboard Extension targets with an App Group wired and the Rime Directory created. On a real device, measure: (a) whether a free Personal Team can use App Groups on-device or a paid program is required; (b) App Group read/write from the keyboard with and without Full Access; (c) empty-extension memory and cold-start baseline; (d) duration of copying ~40 MB of dummy baseline data. Also decide the Apple Developer account type (individual vs organization) — it sizes the D-U-N-S lead time needed by ticket 19. Record all results here; the harness lives on branch `prototype/01-platform-spike` and is never merged to main.

## Acceptance criteria

- [x] Project skeleton (app + keyboard extension) builds and runs (simulator verified; device pending human run)
- [ ] App Groups free-vs-paid answer recorded with evidence (device)
- [ ] App Group read/write matrix with/without Full Access recorded (device)
- [ ] Empty-extension memory + cold-start numbers recorded (device)
- [ ] Dummy seed-copy duration recorded (device)
- [ ] Account-type decision (individual vs org) recorded
- [x] Harness pushed to a prototype/ branch

## Results so far

- Harness + runbook: `prototype/platform-spike/` on branch `prototype/01-platform-spike` (commits 183c8c0..d468ad2). Runbook: `prototype/platform-spike/RUNBOOK.md`.
- Simulator (plumbing only): group read/write OK with simulated signing; **nil container URL with `CODE_SIGNING_ALLOWED=NO`** — App Group needs valid provisioning even on simulator. Seed benchmark copy: 40 MB / 200 files in 0.03 s (host SSD, meaningless for device).
- Code review (two axes) done; cold-start probe fixed to use kernel process start time (`sysctl kinfo_proc`).
- Remaining: human runs RUNBOOK.md steps A–D on a paired device and posts numbers here.
