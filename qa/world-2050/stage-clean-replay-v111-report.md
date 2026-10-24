# P0 stage clean replay and off-database backup content parity (24 Oct 2026)

**Only read-only SQL was executed against isolated Supabase stage `sozrygjxjotozrsenred`; no reset or replay happened.** Production and its private saves were untouched.

## Proven clean replay boundary

Reproducible SQL: `qa/world-2050/stage-clean-week-plan-v111.sql`.

- First 12 weekly windows 2026-01-04 through 2026-03-29 checked against current frozen tournament schedule and the persisted job roster.
- **Seven clean calendar weeks** from 2026-01-04 through **2026-02-22** have 0 invalid fixtures.
- The **last pre-contamination week**, 2026-02-15→02-22, was also verified using the **semantic v96 receipt**: `ok:true`, 17 tournaments, 527 completed matches, 311 ranking awards, 0 invalid calendar events, 0 match effect duplication and 0 duplicate ranks.
- **First contaminated week** is 2026-02-22→03-01 (one cancelled ITF event).
- Clean replay would exclude **7 bad scheduled event rows** across five later weekly jobs: **6 already simulated** and **1 pending**. Exclusion counts per week ending March 1/8/15/22/29: **1/1/1/2/2**. Clean eligible events per week ending those dates: **16/15/18/17/23**.
- This is a `world_singles_only` calendar plan, not a working resimulation or a guarantee of 2025 ATP historical validity.

## Stage original-player snapshot discrepancy

Reproducible SQL: `qa/world-2050/stage-original-player-drift-v111.sql`.

The old checkpoint-preservation function `verify_original_fixture_rows_v3()` **failed** at `players`, reporting **2,302 changed original player records**, but direct ID equality shows **0 of 5,391 original player IDs missing**. Drift in selected columns: 2,254 `game_world_rank`, 185 ATP `ranking`, 383 `fitness`, 365 `fatigue`, 360 `form`. Name/country/birth-date/source origin differences are all **zero**. Multiple fields can change in the same row, so counts are NOT additive. Change does not by itself prove corruption; these values can evolve during valid matches as well.

The invalid events involved **188 distinct players**, of which **four** occur among the 5,391 original checkpoint rows. It would be unsafe to patch only those four: simulator effects can be cumulative and rankings, headlines, awards, and shared recovery clocks can involve other players indirectly.

## Independent backup gate improved

`scripts/cb-stage-independent-backup-verify.sh` now hashes **all rows of 12 selected critical tables**, using canonical JSONB per-row MD5 and a sorted aggregate fingerprint per table:

1. Pre-dump staging fingerprint.
2. Post-dump staging fingerprint, abort if changed during Supabase CLI's separate export sessions.
3. Post-restore local fingerprint, abort if it differs from the staging pre-dump state.

It also retains numeric row count checks, encrypted age archive and SHA256. Digest parity is stronger than count-only and prevents claiming success after same-row-count data changes. **It is not a complete database-wide content parity test, nor a full 2025 world/2050 certification.** SQL dump+restore still requires user-authorized PostgreSQL credentials, offline encryption identity, and local Postgres 17 setup. The available connector cannot furnish such an independent backup, so none has been executed in this chat.

## Strict continuation rule

1. Execute full off-database backup and local restore with digests equal.
2. Reconstruct clean world in **a separate disposable restored environment**, not by deleting affected rows on original stage.
3. Verify all 2025 snapshot source/circuit identities, 24,435 generated players, 26,456 rank plan and historical ledger.
4. Replay **from before the 2026-03-01 invalid fixture** and prove every week with semantic v96 plus actual match/points/H2H/title/recovery/save-load receipts.
5. Only then consider replacing/restarting the isolated long-term 2050 QA controller. Never certify doubles/juniors/NCAA/Davis based on a singles-only receipt.

P0 #105 remains blocked until the independently restored database exists.
