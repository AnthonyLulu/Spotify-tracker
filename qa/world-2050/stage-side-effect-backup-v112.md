# P0 v112: backup coverage for world tournament side effects

## Live isolated-stage evidence, 24 Oct 2026

Read-only SQL `qa/world-2050/stage-side-effect-footprint-v112.sql` checks the simulated explicitly inactive/cancelled/postponed tournaments without changing data.

The observed six cancelled/postponed ITF events have 330 match rows including qualifying, 660 stat rows, 96 ranking-point award rows, six title rows and 188 distinct participants. All 188 player IDs also have `player_training_load_profiles` rows; 13 have some injury history. **These training and injury rows are not necessarily caused by invalid match events**, because those players also have valid matches. The rollback domain cannot be reduced to ranking points alone.

## Hardened backup proof

The operator-only encrypted backup script now compares hashes **and counts of 26 critical tables** before export, after export and after a separate local restore. The fourteen additional covered tables include world match stats, titles, historical ranks, simulated-world draw state, qualification/acceptance, physiology, injuries, records, world story news, finances, player tournament history and qualifying states.

A single combined 26-table fingerprint SELECT timed out under the 19-second staging connector statement limit. We split the routine into three deterministic groups of **12, 7, 7**, then merge sorted JSON digests in Node. Both seven-table groups were independently executed successfully as read-only SQL against Supabase stage; the previous original 12-table group was independently tested. This proves each component query computes valid MD5 digests. **The complete shell dump + local restore still has not run** because the connector provides no authorized database connection string and local age decryption key.

The SQL hashes are MD5 checksums over canonicalized row JSON, meant for accidental data corruption detection, not protection against a malicious actor. The encrypted age archive protects confidentiality; signed/authenticated external backup storage remains the operator's responsibility.

## Go/no-go

Production untouched. Do not run stage cleanup/restore or resume the blocked March 22-29 replay until there is a physically independent verified backup and a restore in an authorized disposable environment. The 2050 E2E career remains **NOT CERTIFIED**. See issue #105.
