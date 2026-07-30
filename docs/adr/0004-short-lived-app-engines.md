# Short-lived Engines for Container App Deploys

The Container App performs each Deploy on a freshly created Engine that is shut down immediately afterwards, instead of keeping one Engine alive. The User Dictionary is single-writer (LevelDB, see ADR-0001): a live Engine holds it open, so a long-lived app-side Engine would silently disable keyboard learning whenever the app had been opened. librime's finalize → re-initialize cycle was previously assumed unsafe from community folklore; CorianderLifecycleTests verifies it works on the pinned librime 1.17, so Engines may be created per task. The Keyboard Extension is unaffected — it keeps its own single long-lived Engine and never Deploys.

## Considered Options

- **Keep the app Engine alive for the process lifetime** — rejected: holds the User Dictionary open while the app sits backgrounded, disabling keyboard learning until iOS reaps the process.
- **Shut down on background, re-initialize on foreground** — rejected as needless churn: Deploys are the only app-side Engine work, and a per-Deploy Engine is simpler than app-lifecycle bookkeeping.

## Consequences

- The app-side Engine holds the User Dictionary lock only for the duration of a Deploy (seconds). A Deploy can still race a live keyboard Engine — then the keyboard keeps the lock and the Deploy's User Dictionary maintenance is skipped (librime tolerates the contention); compiled artifacts are unaffected.
- The Engine permits one live instance per process; `shutdown()` releases the slot, and a later Engine may start in the same process.
- The finalize → re-initialize cycle is load-bearing and guarded by CorianderLifecycleTests; if a future librime upgrade breaks it, the Container App must switch to a keep-alive lifecycle and accept the learning pause.
