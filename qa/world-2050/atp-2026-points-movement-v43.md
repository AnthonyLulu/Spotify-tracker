# ATP movement V43, 10 October 2026: tested behaviour

**Rule source:** ATP official rankings FAQ, ATP Live Rankings FAQ (2026).
A former counted ATP 500 final is **330 points**. After approximately
52 weeks that result expires. The number leaving the breakdown is
not necessarily the change in the player's ATP point total: a
previously non-counting optional result can become counting.

## Existing production-derived logic (before V43)

- `atp_defending_points_ledger`, `world_ranking_points`, `atp_event_pool`,
  `atp_player_breakdown`, `atp_player_ranking_summary`,
  `atp_points_to_defend` and `refresh_world_rankings` already exist.
- The 2026 rulebook's base is 18 eligible results (4 GS + 8 mandatory
  M1000 + 6 best others), plus eligible Finals result.
- `court-boss/modules.js` already showed `−NNN` for event breakdown
  but the weekly total was positive and unlabeled as **gross**;
  users could confuse it with an exact net point loss.

## V43 changes

- Adds `atp_points_movement_v1(player,date_before,date_after)`:
  **read-only**, uses existing ATP summary on both dates, reports
  `points_before`, `points_after`, `expired_counted_points`,
  `net_change_points` and `other_effects_points`.
- `other_effects_points` is NOT always pure replacement credit:
  actual newly earned future results and any other counting changes
  can contribute. Each change is grounded in the existing breakdown
  rules; never infer a loss from expiring gross alone.
- The season screen now explicitly shows gross negative expiry
  (`−330 pts`), an estimated flag when applicable, and explains
  the distinction from net change.
- The function is not yet wired into the API's seasonal ledger
  response, so the net figure is **verified in SQL but not shown as
  a live per-player metric in the mobile UI**. UI continues to
  show accurate underlying gross expirations and the note.

## Real stage SQL proof

In `court-boss-e2e-2025-2050`, a transaction-only probe injected
mock tournament rows for a synthetic user without prior ledger events:

| Scenario | Before | After | Gross dropped | Other effects | Net |
|---|---:|---:|---:|---:|---:|
| ATP 500 final, no replacement | 330 | 0 | 330 | 0 | −330 |
| ATP 500 final and reserve +100 among best 18 | 3730 | 3500 | 330 | +100 | −230 |

The probe returned `ok=true`, `rolled_back=true`. No mock event
rows persisted and no user saves were changed.

## Historical 2025 caveat

The isolated stage's 2,021 imported ATP profiles currently have a
**synthetic aggregate reconciliation** row expiring 2026-11-30, not
an independently verified tournament-by-tournament 2025 breakdown.
Therefore its initial 2026 defence curve is **not historically
credible** and must never be presented as true official weekly 2025
point-defending data. Historic point-per-tournament provenance,
mandatory slots, Monte Carlo and doubles require further validation.
The `court-boss/data/atp-singles-2025-12-01.json` file has a
frozen top-200 reference (Alcaraz #1, Sinner #2) for comparison.

No live database migration, production player data, user saves or
paid infrastructure were touched by this test.
