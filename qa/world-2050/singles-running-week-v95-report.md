# Running singles week: safe progress audit (24 October 2026)

The March 1–8, 2026 isolated job was started after the eight prior weeks (Jan 4→Mar 1) completed: expected 16 events, 0 saved careers, 0 save slots, original fixture checkpoint present. Two events were initially confirmed with 62 matches and 32 award rows. A subsequent writer returned `busy`, so no competing writer or uncontrolled retry was triggered.

**Bug fixed:** `isolated-singles-chain-fast-v94.sql` previously tried `verify_persisted_singles_week_v80` on the newest job even if it was still running. The strict receipt necessarily rejects an incomplete week, causing reports to fail midway through perfectly resumable progress. The query now uses only the most recent fully persisted week for its one expensive live rank check, and independently emits the running week's committed items. It never declares a completed world when one week is running.

**Real stage proof:** during ongoing work, the amended query returned 8/9 fully persisted weeks, Jan 4→Mar 1; 122 finished tournaments, 3866 finished matches, 2353 award rows; the running Mar 1→8 week had 5/16 tournaments, 155 matches and 80 award rows; the latest finished strict receipt remained true. It correctly returned `all_started_weeks_completed=false`, `full_unified_circuits_certified=false`, `2050_certified=false`.

This patch is SQL QA only, no schema mutation or production load. Do not replay the current week in parallel; use persisted `world_week_jobs_v1` and `world_week_items_v1` as the only authoritative resume position. The full 2050, other circuits and real save/load remain P0.
