# Court Boss: real Dec 2025 / Jan 2026 daily world replay

Measured on the **isolated Supabase** stage only on 10 October 2026.
No game save or career row remains after the test.

## Exact results

- Actual SQL `advance_career_day_v26`: **36 successive days**, from
  2025-12-01 through the new date 2026-01-06, **36 daily commits**
  recorded inside the rollback-only test transaction.
- Actual SQL `simulate_world_week` and `mark_weekly_checkpoint_v22`:
  **five** weekly checkpoints, 2025-12-07, 12-14, 12-21, 12-28,
  and 2026-01-04.
- Real `rollover_season_daily_v22(2026)`: **one** completed crossover,
  3,358 temporarily seeded licensed names, 2,000 classified junior
  singles and 2,000 doubles.
- One repeat 2026-01-05 request yielded `already_applied=true`,
  with **one** recorded 2026-01-05 daily commit.
- World ranked active players at checkpoints: 31,830; 31,830; 31,830;
  31,830; **33,626** after 2026 newborn/junior progression.
- 2025-12-07 world recovery updated 1,800 players, later Sunday
  checkpoints performed their real-world calls. A 2026-01-04 world
  recovery updated 211 players.
- Forced exception rolled back **every** test write.

## Problems caught and corrected before this replay

- The original first 10-day Sunday checkpoint failed after six days
  with `career_state.singles_rank NOT NULL` due to a managed player
  dropping to zero ATP points. Fixed and replayed in stage; versioned
  in merged PR #56.
- Previous season button invoked weekly `rollover_season` and could
  fall back to 5 January. PR #56 forces `daily_mode:true`.
- Purely offline 9,161-day stub adapter tests are **not** a substitute
  for these real SQL calls.

## NOT YET CERTIFIED

This is a **36-day rollback-only test**, not a full daily world replay
through 2050. Staging still lacks an isolated authenticated Edge
Function, externally verified disaster-recovery backup, historically
faithful ATP baseline tournament-level results (#54), and tested
mid-match save/load/crash fault injection across year transitions.

One managed player's game-world rank became null on a 0-point ATP
week, while its non-null `career_state.singles_rank` preserved the
last known rank as a compatibility fallback. That is not the correct
final user-facing NR representation, and this remains a P1 display
and rank-source separation issue.
