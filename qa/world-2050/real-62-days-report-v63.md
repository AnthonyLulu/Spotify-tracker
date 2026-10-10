# Real 62-day career/world replay: 10 October 2026

The existing isolated free Supabase E2E project was used. No
production stress, writes to live user saves, or paid resources.

The exact `probe_real_december_february_v12()` function performed:
- 62 sequential actual `advance_career_day_v26` calls, 2025-12-01 to
  2026-02-01. 62 distinct daily tick commits and no missing days.
- 8 actual Sunday `simulate_world_week` calls, each followed by the
  real `mark_weekly_checkpoint_v22` checkpoint.
- An actual `rollover_season_daily_v22(2026)` at December 31 with
  temporarily imported 3,358 licensed name records and 2,000 singles
  plus 2,000 doubles junior rank slots.
- Retry on 2026-01-31 returned `already_applied=true`, with exactly
  one daily journal event for that date.
- Ranked-active-world snapshots on Sundays: 31,830 × 4 before the
  crossover, 33,626 × 4 afterwards. The managed 0-point ATP profile
  is deliberately unranked after Sunday while last valid career rank
  is kept non-null for compatibility by the previously merged P0 fix.
- All game writes were rolled back by the probe's exception subtransaction,
  including the new 2026 player and licensed name imports.

**Uncertified:** the complete 2025–2050 daily run, production API
and real mobile save/reload, isolated Edge Function, independent
external backup, ATP 2025 detailed point-drop seed, several later
season retirements and world population checks. This evidence is a
bounded 62-day test and nothing more. Do not claim 2050 certification.
