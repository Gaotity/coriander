# 11 — CI pipeline (quota-aware)

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 07
**Status:** done

## What to build

GitHub Actions macOS workflow that builds both targets and runs XCTest. Frugal by design: the repo is public so Actions is free, but keep it lean anyway — cache the XCFramework keyed by the pinned librime version (rebuild only when the pin changes), trigger only on code-path changes, skip docs-only changes.

## Acceptance criteria

- [x] Workflow builds both targets and runs XCTest green on a PR
- [x] XCFramework cache hit on the second run (no dep rebuild)
- [x] Docs-only change does not trigger a build

## Results

- `.github/workflows/ci.yml` is the only new file. It triggers on PRs and pushes to `main`, restricted to code paths (`src/**`, `tests/**`, `vendor/**`, `scripts/**`, `project.yml`, `.github/workflows/**` — including its own path so the PR adding it triggered itself); docs-only changes never start a build. Read-only token, concurrency cancel-in-progress, 90-minute cap.
- `actions/cache` restores exactly the path `project.yml`'s `RIME_XCF` points at (`.scratch/librime-deps/Rime.xcframework`), keyed by `hashFiles` of the three `scripts/librime/*.sh` — the librime and boost pins live in `fetch.sh` / `build-deps.sh`, so a pin change is a different key. No `restore-keys`: a pin change must be a clean rebuild, not a stale overlay. Dependency tooling (`cmake`/`ninja`/`bash`) and the three build scripts are gated on cache miss; `xcodegen` installs every run (cheap), and the test command is byte-identical to the README's.
- Runner reality found by CI: `macos-latest` ships bash 3.2 at `/bin/bash`, and `build-deps.sh` uses associative arrays (`declare -A`), which bash 3.2 evaluates into `iphoneos: unbound variable` — reproduced locally with bash 3.2.57 before fixing. CI now installs Homebrew bash and invokes the three scripts with it explicitly. The scripts still fail on any stock macOS without Homebrew bash; lifting that (README requirement or script rewrite) is deliberately left out of this ticket.
- Evidence (PR #46): first run failed on the bash 3.2 issue ([run 30532175894](https://github.com/Winn-Gaoti-Studio/coriander/actions/runs/30532175894)); second run — cache miss, full librime rebuild, ~14 min — green ([run 30532799280](https://github.com/Winn-Gaoti-Studio/coriander/actions/runs/30532799280), criterion 1); re-run of the same workflow logged `Cache restored from key: rime-xcframework-982c5b0d…`, skipped both dependency steps, green in 2m43s ([attempt 2](https://github.com/Winn-Gaoti-Studio/coriander/actions/runs/30532799280/attempts/2), criterion 2). Criterion 3 holds by the paths whitelist (config review; this very docs update is a live demonstration — it does not start a build).
