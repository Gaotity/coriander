# App-side Deploy, keyboard-side input

Both the Container App and the Keyboard Extension embed their own Engine (librime instance), but the roles are split: the Container App owns Deploy (including Import validation), while the Keyboard Extension only runs input Sessions against already-deployed artifacts in the shared Rime Directory. iOS keyboard extensions have tight, undocumented memory budgets and are killed aggressively by the system; running a librime Deploy (seconds to tens of seconds of CPU/IO, large memory spikes with big dictionaries) at keyboard cold start would be slow and risks jetsam termination. Squirrel can deploy in-process because macOS input methods carry no such constraints; on iOS the heavy work must live in the app. Two consistency rules follow: a Deploy invalidates the in-progress Session (the next Session loads the new artifacts — no hot swap), and only one Engine holds the User Dictionary open at a time (LevelDB is single-writer), so the Keyboard Extension is its sole writer during input.

## Considered Options

- **Keyboard-side Deploy** (Engine exists only in the extension) — rejected: unacceptable cold-start latency and termination risk on every schema change.
- **Hot reload of Sessions after Deploy** — rejected: implementation complexity for negligible UX gain; keyboard processes are recreated by the system constantly anyway.

## Consequences

- librime is linked into two binaries, increasing app size.
- Schema changes made in the Container App become visible in the keyboard only on the next Session.
- Any future feature running an Engine in the Container App (e.g. input preview) must respect the single-writer rule for the User Dictionary.
- Persisting the User Dictionary from the keyboard requires Full Access; without it the keyboard reads the Rime Directory read-only and learning is disabled (see ADR-0003).
