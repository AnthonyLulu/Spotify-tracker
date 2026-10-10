# Tennis Manager 2025–2050, 10 October 2026: stage rank seed V50

**Environment:** `court-boss-e2e-2025-2050` only. No production schema
or data modified; do not use this script as a production migration.

### Independently verified stage seed

- Existing archived fixture: 85 tables in the internal checkpoint, 5,391
  original players and 5,000 original attribute records.
- Imported 2025 ATP supplemental reference: 2,021 players with ranks
  1..2206, including 699 tied rank entries across 123 duplicate groups.
  Every import initially had `ranking_current=true` despite colliding with
  the preexisting 5,375 assigned game-world ranks.
- Synthetic adults: 24,435. Combined active stage: **31,831**.
- Defined a private, deterministic plan with 26,456 new stage-only IDs,
  rank assignments 5,376..31,831, unique player/rank indexes.
- Ran one 500-row canary, then 18 bounded calls (17 × 1,500 and 456).
  At completion **31,831 active players, 31,831 distinct contiguous game
  ranks 1..31,831, 0 missing**.
- The original 5,375 ranks and all 85 checkpoint table projections
  retained their recorded content (the two separately audited calendar
  overrides remain the only accepted baseline changes).
- Imported ATP `ranking` numeric source values were kept unchanged;
  `ranking_current` was changed **only on the 2,021 stage-only supplemental
  imported players** to avoid live simulation overwriting their unique
  game rank with duplicate historical `ranking` values.
- Isolated world guard 2025-12-01 returned `ok=true`; the cached world
  rank count is 31,831. No stage career or game saves remained.

### Real boundary scenario

- Two concurrent staging activities caused a deadlock while one ran
  rollover/Jan 1 tick and the other generated 31,847 Elo/development
  profiles. PostgreSQL logs show two distinct management sessions with
  conflicting locks on player/recovery and archived fixture tables.
- After the other stage migration committed and the stage was idle,
  **one** rerun of the rollback-only real-engine probe
  `probe_daily_dec31_to_jan1_retry_v6()` returned:
  `ok=true`, `date=2026-01-01`, 0 skipped days, 1 daily training
  result, `already_applied=true` on repeated Jan 1 request,
  **exactly one** `daily_tick_commit_v25`, junior singles and junior
  doubles 2,000 each, `rolled_back=true`.
- The stage now also has 31,847 development profiles and 31,847 Elo
  baseline rows from a separate approved preparation operation. The
  checkpoint guard was rerun afterwards and passed.

### Limitations

- Stage's initial 5,000 baseline simulated players and the supplemental
  ATP imports are **not a validated historical ATP singles ranking**.
  Preserving both without rank collisions supports engine E2E testing, not
  a claim that Sinner/Alcaraz et al. are at their proper 2025 world rank.
  Gameplay fairness and ATP seed reconciliation remain separate.
- The stage has no isolated authenticated game Edge Function yet, no
  verified external backup, and a remaining function digest drift.
- One season-boundary success is not a day-by-day 2025–2050 simulation,
  nor a pass for crashes during live match/save-load or final long-run
  economy/retirement/Hall of Fame checks.
- Never run concurrent stage world migrations and rollover/replay probes.
  Require single-owner serial orchestration and explicit bounded test
  budget before broad E2E. Keep issues #10 and #18 OPEN.
