# Issue tracker: local docs tickets

Internal tickets (specs, implementation tickets) live in the repo as Markdown files, not on GitHub.

## Layout

- **Spec**: `docs/spec/<slug>.md`
- **Tickets**: `docs/tickets/<NN>-<slug>.md`, numbered from `01` in dependency order (blockers first), one ticket per file.

Ticket file template:

```md
# <NN> — <title>

**Parent spec:** [docs/spec/<slug>.md](../spec/<slug>.md)
**Blocked by:** <numbers of gating tickets, or "None — can start immediately">
**Status:** ready-for-agent | in-progress | done

## What to build
...

## Acceptance criteria
- [ ] ...

## Results
(filled in as work lands — measurements, decisions, pointers to branches)
```

## Operations

- **Create**: write a new file with the next free number, dependencies first.
- **Read / list**: read the files directly; the **frontier** is any ticket whose blockers are all `done`.
- **Update**: edit the file — status, results, decisions. Commit alongside the work.
- **Close**: mark `Status: done` once every acceptance criterion is checked.

## Blocking

Blocking edges are the `Blocked by:` lines in each ticket header. A ticket is unblocked when every ticket it lists is `done`. Work the frontier, blockers first.

## GitHub's remaining role

GitHub issues are now **only the external inbox** — bug reports and requests from outside. They run through the triage labels in `docs/agents/triage-labels.md` (`/triage`, `/qa`); when one is accepted, convert it into a local ticket and close the GitHub issue with a pointer to the file.

PRs, reviews, and releases stay on GitHub as before — see the workflow rules in `AGENTS.md` (branch, `gh pr create --assignee @me`, `codex-pr-finalize`, review triggers).

`gh` CLI usage for that external surface:

- **Create an issue**: `gh issue create --title "..." --body "..."` (heredoc for multi-line).
- **Read**: `gh issue view <number> --comments`; **comment**: `gh issue comment <number> --body "..."`
- **Label**: `gh issue edit <number> --add-label "..."`; **close**: `gh issue close <number> --comment "..."`
- Infer the repo from `git remote -v`.
- The active `gh` account may not own this repo — use `GH_TOKEN=$(gh auth token --user Gaotity) gh ...` for writes on `Winn-Gaoti-Studio/coriander`.
