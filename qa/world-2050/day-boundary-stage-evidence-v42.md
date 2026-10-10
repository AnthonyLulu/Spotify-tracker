# Daily year-boundary V42: isolated staging test evidence

This is source control for a verified **staging-only** patch; the migration has
**not** been executed against production.

- Baseline engine: `advance_career_day_v22` rejects a Dec 31 -> Jan 1 tick
  until `rollover_season_daily_v22(2026)` completes.
- Discovered side effect: `refresh_world_rankings(2026-01-01)` inside the
  daily rollover updates `career_state.career_date` prematurely to January 1.
- Patch leaves season-specific setup and junior singles/doubles rank refresh
  intact, then sets `career_date` back to 2025-12-31, allowing the **real**
  `advance_career_day_v26` to commit Jan 1 exactly once.
- A rollback-only probe in the isolated project successfully executed
  season rollover followed by the actual Jan 1 daily tick: `ok=true`,
  `from_date=2025-12-31`, `date=2026-01-01`, training/recovery present,
  2,000 ranked juniors in singles and doubles, and `rolled_back=true`.
- A second stronger probe intended to check the duplicate Jan 1 request
  **timed out (SQLSTATE 57014)** inside `refresh_game_world_ranks` while
  generating newgens, before it could reach the retry assertions. The
  duplicate-request E2E gate is therefore **UNVERIFIED**, not green.
- The staged database has no persisted user career or game saves following
  the probes; no production writes, no live 25-year stress run.

**Before a production deployment:** diagnose the world-rank timeout,
validate the duplicate Jan 1 retry, and run the real authenticated Edge
Function/mobile flows in an isolated environment. Continue to keep issues
#10 and #18 open and `is_2050_certified=false`.
