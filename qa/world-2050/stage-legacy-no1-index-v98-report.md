# Isolated stage legacy ranking query index, 24 October 2026

The 2026-03-22→03-29 world-singles replay hit PostgreSQL SQLSTATE 57014 while inserting a title. The trigger `court_boss_record_title_trigger` invokes `court_boss_publish_title_legacy_story`, which calls `court_boss_publish_legacy_rank_story`. That function computes the full `court_boss_legacy_leaderboard` for the prior and current day; the `future_no1` aggregate previously scanned roughly 126,533 `ranking_history` records because its existing index was `(player_id, snapshot_date)`.

The isolated stage was guarded (original checkpoint exists, zero career rows, zero saves and zero save slots) and the narrow **partial index** `cb_e2e_legacy_rank_history_no1_date_v96` on `(snapshot_date, player_id) WHERE ranking=1` was created through the Supabase staging migration `stage_legacy_no1_ranking_history_idx_v96`. An independent read-only `EXPLAIN` confirms an **Index Only Scan**, planner cost ~4.76 for the leaf, replacing the previous sequential scan cost ~3321. Neither running match simulations nor legacy record functions were altered by this index.

**Not an E2E fix claim.** The next replay attempt encountered a *different* fail-closed calendar check: `invalid_calendar_events`. Stage already contains cancelled ITF fixtures, which is independently documented in issue #105. The index has not earned a full-week runtime benchmark or repaired the calendar. Do not expand simulation or merge this as a production migration. Keep historical score/titles/awards intact; do not delete or disable the news trigger to hide the timeout.

Scope: QA/stage-only SQL reference and one offline safety test. Production database, game saves and Render match physics are unchanged.
