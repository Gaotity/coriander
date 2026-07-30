# 09 — Deploy pipeline in the Container App

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 07
**Status:** done

## What to build

Container App Deploy action with progress and error reporting; last-good artifacts preserved on failure. The Engine gains its deploy interface here (first need). Seam tests assert: a new Session loads the new artifacts, and a failed Deploy leaves typing intact.

## Acceptance criteria

- [x] Deploy runs with visible progress and clear errors
- [x] Failed Deploy preserves last-good artifacts
- [x] Seam test: new Session loads new artifacts
- [x] Seam test: failed Deploy keeps typing intact

## Results

- The Engine gains `deploy() throws` (first need): `start_maintenance` + `join_maintenance_thread` + verification, throwing `DeployError` (`notRunning` / `failedToStart` / `schemasFailed([ids])`). `init` loses its `deploy:` flag — all callers now compose `Engine(directory:)` + `deploy()` explicitly (keyboard: init only; app/tests: init + deploy).
- Failure detection is evidence from the seam test, not assumption: librime preserves the previous artifact when a schema compile fails (natural last-good — typing kept working in the probe), so a failed Deploy is detected by artifacts missing or older than their sources. Dictionary-table failures are not detected (noted in code). **Probed and documented:** broken custom patches are silently ignored by librime (full Deploy and `deploy_schema` both report success, patch silently not applied — pinned by `testBrokenCustomPatchIsTolerated`), so Deploy cannot validate user-edited config syntax; tickets 10/21 must validate before Deploy.
- Container App Deploys run on short-lived Engines (create → deploy → shutdown), releasing the User Dictionary for the keyboard within seconds. This is viable because librime 1.17's finalize → re-initialize cycle is verified by the new isolated `CorianderLifecycleTests` target (the probe finalizes librime and must not disturb the main suite's shared Engine). Decision recorded in ADR-0004; `Engine.shutdown()` now releases the one-live-Engine slot.
- App UI: blocking indicator + stage text ("Deploying…" → "Deploy complete" / "Deploy failed: <schema ids>") behind a "Deploy now" button; first-launch bootstrap unchanged in shape (seed → deploy → shutdown → marker).
- Observed during tests: librime's logger prints `COULD NOT CREATE A LOGGINGFILE` in the test sandbox (no log dir configured) — cosmetic only, unresolved.
- App smoke (device, 2026-07-30, human run): first-launch bootstrap, then "Deploy now" → "Deploy complete". The failure path is covered by the seam test (a user-reachable broken yaml only arrives with ticket 10's Config Folder).
