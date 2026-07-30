# 21 — Import schemas with validation and rollback

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 10
**Status:** ready-for-agent

## What to build

Import schema files or archives via document picker or share sheet: merge them into the Config Folder (overlay only, never deletes), validate, and roll back entirely on failure (spec user stories 15-17 — the ticket split originally missed this one). Validation cannot rely on Deploy alone: librime silently ignores broken custom patches (probed in ticket 09), so syntax validation must happen before Deploy — only schema-source compile failures make a Deploy fail.

## Acceptance criteria

- [ ] Import via document picker and share sheet into the Config Folder
- [ ] Overlay only — repeated Imports never delete existing files
- [ ] Invalid input is rejected with a clear error and a full rollback
- [ ] Typing works unchanged after any failed Import
