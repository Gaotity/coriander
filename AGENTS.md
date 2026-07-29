## Agent skills

### Markdown style

Markdown docs in this repo use **soft wrap**: one paragraph per line, no hard line breaks at a fixed column. Let the editor wrap visually. Lists too — one item per line, continuation text stays on the same line.

### Issue tracker

Internal tickets are local Markdown files: `docs/spec/` for specs, `docs/tickets/<NN>-<slug>.md` for tickets with `Blocked by:` edges. GitHub issues are only the external inbox. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
