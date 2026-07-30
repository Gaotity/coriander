# 10 — Config Folder one-way pipeline

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 09
**Status:** in-progress (implemented and seam-tested; Files-visibility smoke pending human run)

## What to build

The Files-visible Config Folder becomes the single source of truth for configuration: one-way pipeline syncs it into the Rime Directory and Deploys; conflicts resolve last-write-wins per file; sync never deletes user files. Changes reach the keyboard after the Container App next runs a sync + Deploy. Note (probed in ticket 09): librime silently ignores broken custom patches, so Deploy does not validate config syntax — user edits that break yaml go unreported unless the pipeline catches or surfaces them.

## Acceptance criteria

- [ ] Config Folder visible in the Files app
- [ ] Edit in Files → open app → keyboard reflects the change
- [x] Conflicting edit resolves last-write-wins per file
- [x] Sync never deletes user-side files

## Results

- `ConfigFolder` (`src/Engine`) models the Files-visible folder — `Rime Config` inside the Container App's Documents, exposed through `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` in the app's Info.plist. `seedIfNeeded` plants the baseline's `default.custom.yaml` (the schema_list switch) exactly once, tracked by a hidden `.seeded` marker: a Files edit is never overwritten, and deleting the file does not resurrect it — last-write-wins per file. `sync(into:)` recursively overlays the folder onto the Rime Directory's `user` side: copies only content that differs, skips hidden files and directories, never deletes, and returns the changed relative paths so the app Deploys only on change.
- `RimeBootstrap` is the ADR-0002 ritual: first launch seeds the Rime Directory and the Config Folder and runs the first Deploy; every later app open — and the renamed "Sync + Deploy" button — runs seed-if-needed → sync → Deploy-if-changed, reporting "Synced N file(s): … — Deploy complete" or "no config changes".
- Propagation to the keyboard is closed and probed: librime's WorkspaceUpdate records `var/last_build_time` in `user.yaml`, the keyboard watches it (`RimeDirectory.lastDeployTime`) on every presentation, and when it changes the keyboard restarts its Session — a Session restart is enough to load externally Deployed artifacts even after the process cache warmed (pinned by `testSessionRestartPicksUpNewArtifacts`, which rewrites an artifact on disk between Sessions). The build-time marker lives process-wide on `KeyboardEngine`, not in the controller: iOS creates new `UIInputViewController` instances in a warm process while the Session lives on, and an instance-level snapshot masked exactly that staleness (found in the first device smoke: keyboard showed the old page size despite a fresh Deploy).
- **Root cause of the device smoke failure, found by on-device diagnostics:** `sync` computed relative paths by string arithmetic on `root.path`, but on device the enumerator yields canonical `/private/var/...` paths while `urls(for:)` returns symlinked `/var/...` — the mismatch mangled `luna_pinyin.custom.yaml` into `yin.custom.yaml`, so the patch sat in the Rime Directory under the wrong name and librime never saw it (deploy ran, rebuilt nothing, artifact stayed page_size 5, and later syncs matched the mangled copy and reported "no config changes"). `sync` now resolves symlinks on both sides before computing relatives; regression pinned by `testSyncResolvesSymlinkedRoot`. Simulator never caught it because its paths carry no such symlink hop.
- **Probed:** librime's rebuild trigger compares *second-precision* mtimes recorded in each artifact's `__build_info/timestamps`, so an edit landing in the same second as the previous build is invisible to it. Irrelevant for human rituals (the previous build is always older), but it broke the back-to-back test ritual — the money test backdates the first patch deterministically. This is also why `sync` detects changes by content, not mtimes.
- `project.yml` now pins `DEVELOPMENT_TEAM` — Xcode UI team selections were wiped on every `xcodegen` regeneration, causing intermittent signing failures.
- Broken custom patches remain silently ignored by librime (ticket 09 probe) — validation is ticket 21's job; the app surfaces the synced file list so a silent ignore is at least visible. Widened blind spot, tracked in ticket 17: `Engine.failedSchemas()` only scans the `shared` side, so a broken schema arriving via the Config Folder (into `user/`) compiles and fails silently.
- Smoke pending (human): Config Folder visible in the Files app; edit a custom patch in Files → open the app → "Synced 1 file(s)… — Deploy complete" → the keyboard reflects the change on next presentation.
