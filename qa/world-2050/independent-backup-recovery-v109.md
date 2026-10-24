# Court Boss isolated stage: external encrypted backup + restore gate

**Date:** 24 Oct 2026. **Stage:** sozrygjxjotozrsenred, PostgreSQL 17. **Production:** do not access.

## What was actually checked with live read-only SQL

- Staging is ACTIVE_HEALTHY. Approximately **334 MB** at audit time.
- 12 persisted world-singles weekly jobs: 11 complete, one invalid paused 2026-03-22 to 2026-03-29.
- 0 user save slots, 0 game saves, 0 active career rows.
- Original 2026-10-10 checkpoint exists but is **stored in the same PostgreSQL database**.
- Six cancelled or postponed ITF tournaments were simulated and awarded points. Every event persisted 55 match rows including qualifiers, 110 match stat lines, one title and 16 points rows. Totals **330 match rows, 660 stat rows, 6 titles, 96 points rows**. These numbers do not represent all indirect ELO/H2H/ranking/fitness/news effects.
- All 375 explicitly invalid 2026-to-2050 fixtures are now marked inactive in stage. This is preventive and **does not reverse** earlier matches.
- The stage calendar semantic receipts refuse certification of the affected weeks, so advancing the polluted job is forbidden. Issue #105 tracks the defect.

## Recovery status

**NO cleanup/restore has been performed.** There is no independently verified, off-database full backup accessible through the connected Supabase action set. We must not reset staging based only on its internal 85-table original checkpoint, which also predates later 30k-player world seeding.

A fail-closed **operator script** is now versioned at `scripts/cb-stage-independent-backup-verify.sh`. It:
1. Requires the *exact* isolated stage host, zero saves/careers, and an *empty, explicitly named LOCAL* destination.
2. Uses the Supabase CLI's logical roles, application-schema and COPY data exports (app schemas: public, court_boss_private, original checkpoint, reconstructed E2E). Supabase-managed auth/storage schemas and storage bucket binaries are not copied.
3. Restores the app SQL into an existing disposable local Postgres/Supabase 17 database, aborting on errors.
4. Compares seven key game/checkpoint table row counts, encrypts the archive with an `age` recipient, then decrypts/lists the artifact and emits SHA-256. This is a **partial integrity proof**, not a full per-table digest or independent gameplay certification.

### Prerequisites (local operator; never paste passwords into chat or GitHub)

Install `supabase` CLI, Docker, PostgreSQL `psql`, Node, `age`, and `sha256sum`. Provision a fresh local Postgres/Supabase 17 scratch database with required extensions and name `cb_e2e_restore_<something>`. Export these five environment values via a local password manager/shell (NOT committed): `CB_E2E_DB_URL`, `CB_E2E_RESTORE_TEST_DB_URL`, `CB_BACKUP_AGE_RECIPIENT`, `CB_BACKUP_AGE_IDENTITY_FILE`, `CB_E2E_BACKUP_DIR`. Run:

```bash
bash scripts/cb-stage-independent-backup-verify.sh
```

The script refuses a remote restore destination and does **not** reset/overwrite stage. Archive and decryption key must be stored separately in secure locations. This script has NOT been executed end-to-end against a real local scratch restore because the required owner database URLs and age private key are not available through the connector. An offline CI test checks the safety contract.

## Next hard restoration gates

After a *real independently encrypted and locally test-restored* backup, build a clean reconstructed world from the original pre-replay checkpoint and post-checkpoint legitimate deterministic seeds. Compare 30k world population, all source/player IDs, 2025 historical ATP residuals, junior/NCAA, staff, and titleholders. Do not reuse contaminated 2026 world state. Rerun Jan 4 onward with semantic v96 and inspect all side-effect tables, rank integrity, save/load, and source provenance.

**Go/no-go:** No claim of fully repaired 2026 world or 2050 certification without genuine independent restore + clean world replay.
