# Handoff — 2026-07-29 (pre-device-session)

State snapshot for continuing Coriander work from any machine. Read this first, then the referenced files. Do not duplicate what they already say.

## Where things stand

- `main` is clean at `d6c0e42`. Everything below is merged: local ticket tracker (`docs/spec/mvp.md`, `docs/tickets/01–20`, `docs/agents/issue-tracker.md`), dependency cross-compile (`scripts/librime/fetch.sh`, `build-deps.sh`), XCFramework assembly (`scripts/librime/build-librime.sh`), third-party licenses (`vendor/licenses/`). Merged PRs: #26, #27, #28, #29. GitHub issues #5–#25 are closed with pointers — GitHub is now external-inbox only.
- Tickets: **01** in-progress (agent half done — see below), **02 done**, **03 done**. Everything else is `ready-for-agent` behind its blockers.
- No open PRs. Working tree clean (`.scratch/` is gitignored build output).
- Prototype: platform-spike harness + device runbook live on branch `prototype/01-platform-spike` (pushed; `prototype/platform-spike/RUNBOOK.md`).

## Next actions, in order

1. **Agent: ticket 04 (link smoke test).** Unblocked. Plan (not started): new branch `feat/04-link-smoke`; minimal app target via XcodeGen linking `.scratch/librime-deps/Rime.xcframework`; on appear, print `RimeGetVersion()` and run RimeSetup/Initialize → create → destroy session → finalize against empty temp data dirs; verify in the `spike-sim` simulator. The device half joins the same device session as ticket 01's runbook (step 2 below). Record results into `docs/tickets/04-link-smoke-test.md`.
2. **Human: one device session (~20 min).** Pair + trust the iPhone, then: RUNBOOK.md steps A–D (ticket 01 measurements — watch especially whether App Groups provisions under the Personal Team, that is the AC 2 evidence); ticket 04 device check (same build, on device). Post numbers + device model/iOS version into `docs/tickets/01` (edit the file's Results section) and `docs/tickets/04`.
3. **Human: decide developer account type — recommendation: individual.** Org needs D-U-N-S (weeks) and gates ticket 19; this is a personal project. Record the decision in `docs/tickets/01`'s Results.
4. After 01's data lands: **06 (vendoring)** unblocks, then **07 (Engine adapter)** — the big one. Agent chain stalls after 04 until then.
5. Ticket 05 (librime-in-extension memory) is also device work; fold into a later device session once 04 is merged.

## Environment gotchas (this machine)

- `xcode-select` still points at Command Line Tools. Builds must export `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (or run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` once).
- iOS 26.5 SDK + simulator runtime installed. Bootable simulator: `spike-sim` (UDID `7EA330EA-5D72-4CC7-A92C-F816125802A4`, iPhone 17 Pro).
- 0 code-signing identities so far — Xcode creates the Personal Team certificate on the first device build (Xcode → Settings → Accounts shows the signed-in Apple ID).
- `gh` global active account may be `terrence-kira`; for writes on `Gaotity/coriander` use `GH_TOKEN=$(gh auth token --user Gaotity) gh ...`.
- Tools installed: cmake 4.4.0, ninja, xcodegen (brew). Xcode 26.6.
- librime pinned at 1.17.0 (boost 1.89.0, deployment target 16.0) — see `scripts/librime/` headers and `.scratch/librime-deps/VERSIONS`.

## Rebuilding the XCFramework from scratch (any machine)

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
scripts/librime/fetch.sh        # clone librime 1.17.0 + submodules into .scratch
scripts/librime/build-deps.sh   # 6 dep libs × 3 slices
scripts/librime/build-librime.sh # Rime.xcframework
```

## Suggested skills for the next session

- `/implement` — tickets 04, then 06/07 as they unblock (one ticket per fresh window)
- `/code-review` — at each ticket close-out
- `/handoff` — when the window fills again
