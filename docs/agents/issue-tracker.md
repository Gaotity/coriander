# Issue tracker: Linear

Internal tickets live in Linear — workspace `wg-studio`, team **Engineering**, project **Coriander**. Specs still live in the repo at `docs/spec/`; `docs/tickets/` is a frozen archive of the pre-Linear local tickets (see its README for the ENG mapping).

## Layout

- **One Linear issue per ticket**, in the Coriander project.
- **Blocking edges** are Linear `blocks` relations, recorded on the blocker's side ("07 blocks 08"). A ticket is workable when every blocker is Done.
- **States**: Todo, In Progress, In Review, Done. Open tickets that are agent-ready also carry the `ready-for-agent` label from the `triage` label group.
- **Descriptions are bilingual** (the project's hard rule for external collaboration connectors): the complete English block first, then `---`, then the complete Simplified Chinese block. Domain and technical terms stay in English per `CONTEXT.md`.

## Operations

- **Create**: one issue in the Coriander project; set its blocking relations to the tickets that gate it; apply `ready-for-agent` once fully specified.
- **Read / list**: the project view; the frontier is any Todo issue whose blockers are all Done.
- **Update**: edit the description (both language blocks), move the state as work lands; record measurements, probe findings, and decisions as they happen.
- **Close**: record the verification evidence in the description, tick every acceptance criterion, then move to Done.

## Linking PRs

- Name branches `eng-NN-slug` (or put the identifier in the PR title/body) so Linear's GitHub integration auto-links once it is installed.
- Regardless of the integration, attach the PR to the issue — the issue should always show its PR sources.

## GitHub's remaining role

GitHub issues are now **only the external inbox** — bug reports and requests from outside. They run through the triage labels in `docs/agents/triage-labels.md` (`/triage`, `/qa`); when one is accepted, convert it into a Linear issue and close the GitHub issue with a pointer to it.

PRs, reviews, and releases stay on GitHub as before — see the workflow rules in `AGENTS.md` (branch, `gh pr create --assignee @me`, `codex-pr-finalize`, review triggers).

`gh` CLI usage for that external surface:

- **Create an issue**: `gh issue create --title "..." --body "..."` (heredoc for multi-line).
- **Read**: `gh issue view <number> --comments`; **comment**: `gh issue comment <number> --body "..."`
- **Label**: `gh issue edit <number> --add-label "..."`; **close**: `gh issue close <number> --comment "..."`
- Infer the repo from `git remote -v`.
- The active `gh` account may not own this repo — use `GH_TOKEN=$(gh auth token --user Gaotity) gh ...` for writes on `Winn-Gaoti-Studio/coriander`.

## Linear API notes

- The API key is `LINEAR_PERSONAL_PROJECT_FULL_ACCESS_API_KEY`, available in the user's interactive zsh environment (`zsh -ic 'printenv …'`). Personal API keys authenticate as the raw `Authorization` header value — no `Bearer` prefix.
- The Coriander project belongs to the **Engineering** team; issue states and the `triage` label group are team-scoped, so always resolve ids against that team (there is also a C-level team with its own labels).
