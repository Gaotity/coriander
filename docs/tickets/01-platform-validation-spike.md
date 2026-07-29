# 01 — Platform validation spike + developer account decision

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** None — can start immediately.
**Status:** done

## What to build

Minimal Container App + Keyboard Extension targets with an App Group wired and the Rime Directory created. On a real device, measure: (a) whether a free Personal Team can use App Groups on-device or a paid program is required; (b) App Group read/write from the keyboard with and without Full Access; (c) empty-extension memory and cold-start baseline; (d) duration of copying ~40 MB of dummy baseline data. Also decide the Apple Developer account type (individual vs organization) — it sizes the D-U-N-S lead time needed by ticket 19. Record all results here; the harness lives on branch `prototype/01-platform-spike` and is never merged to main.

## Acceptance criteria

- [x] Project skeleton (app + keyboard extension) builds and runs — simulator and device (iPhone 15 Pro Max, iOS 18.7.3)
- [x] App Groups free-vs-paid answer recorded with evidence — **free Personal Team works on-device** (no provisioning error; full read/write round-trip in the group container)
- [x] App Group read/write matrix with/without Full Access recorded — **FA off: read OK / write FAIL (permission denied); FA on: read OK / write OK**
- [x] Empty-extension memory + cold-start numbers recorded — memory 63.4 MB (2nd launch) / 82.2 MB (first debug-attached launch); cold start **235 ms** (2nd launch, process init → viewDidLoad) / 17211 ms (first debug launch — noise, ignore)
- [x] Dummy seed-copy duration recorded — **40 MB / 200 files in 0.03 s (~1.5 GB/s)**; app-side resident memory 84.4 MB
- [x] Account-type decision recorded — **individual** (org would need D-U-N-S, weeks; this is a personal project)
- [x] Harness pushed to a prototype/ branch — `prototype/01-platform-spike` (runbook: `prototype/platform-spike/RUNBOOK.md`)

## Results

Device session 2026-07-29, iPhone 15 Pro Max, iOS 18.7.3, free Personal Team signing.

- **App Groups is NOT paywalled.** Everything below ran on a free Personal Team with no provisioning errors. The paid program is needed only for TestFlight/App Store (ticket 19/20).
- **The ADR-0003 tiered model is validated on hardware.** Without Full Access the keyboard reads the shared container but cannot write it (permission denied); with Full Access it reads and writes. Matches Apple's App Extension Programming Guide wording and Hamster's production evidence. Basic typing (read-only) never needs Full Access; persisting the User Dictionary does.
- **Empty-extension memory baseline is higher than folklore, and so is the ceiling.** An empty extension (label + button) sits at ~63 MB resident on this device without being jetsam-killed — the "~30-60 MB keyboard limit" folklore is stale on modern iOS/hardware. Precise jetsam threshold + librime-loaded footprint = ticket 05.
- **Seed copy is a non-issue.** ~1.5 GB/s means first-launch UX is dominated by Deploy, not file copying (informs ticket 06's prebuilt-vs-deploy-on-seed decision).
- Simulator vs device discrepancy confirmed for the record: simulator needed valid provisioning for the group container too, but its Full Access enforcement is untrustworthy — only device numbers above count.
- Earlier agent-side findings (simulator plumbing, cold-start probe fix via `sysctl kinfo_proc`) are in the git history of `prototype/01-platform-spike` and PR discussion of #26–#32 era.
