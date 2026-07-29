# 10 — Config Folder one-way pipeline

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 09
**Status:** ready-for-agent

## What to build

The Files-visible Config Folder becomes the single source of truth for configuration: one-way pipeline syncs it into the Rime Directory and Deploys; conflicts resolve last-write-wins per file; sync never deletes user files. Changes reach the keyboard after the Container App next runs a sync + Deploy.

## Acceptance criteria

- [ ] Config Folder visible in the Files app
- [ ] Edit in Files → open app → keyboard reflects the change
- [ ] Conflicting edit resolves last-write-wins per file
- [ ] Sync never deletes user-side files
