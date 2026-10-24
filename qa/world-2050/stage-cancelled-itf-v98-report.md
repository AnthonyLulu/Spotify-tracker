# Isolated-stage cancelled ITF status freeze v98 (24 Oct 2026)

The real stage data contained **375 explicitly cancelled/postponed ITF event entries**, exactly 15 in each calendar year from 2026 through 2050. All 375 were incorrectly `is_active=true`. Six have already been simulated and awarded a total of 96 point rows, which this correction **does not erase**.

A guarded SQL v98 transaction was first executed with `ROLLBACK`, then committed only in the isolated Supabase project `sozrygjxjotozrsenred`. It stores original status, name and event date for all 375 IDs in private `cb_e2e_reconstruction_20261010.itf_cancelled_original_status_v98` and deactivates only those specific IDs.

Independent post-commit read-only SQL verified:
- 375 original rows preserved and 375 originally active.
- **0 of 375** currently still active.
- All six contaminated tournament simulation records still exist, deliberately untouched.
- 0 staged user careers and 0 staged user saves.
- The v96 semantic receipt + v97 world-week guards remain installed. The old completed weeks that simulated cancelled fixtures remain **NOT CERTIFIED**.

Stage data is recoverable from the captured original fixture statuses; however, this is not a full pre-error world rollback. Before replaying 2026-02-22 onward, the 6 event side effects and any derived ranking/H2H/physical/news effects must be restored atomically using a separate tested full database checkpoint. Do **not** simply delete 96 world point rows.

This stage-only SQL file is deliberately under `qa/world-2050/`, not a live production migration. The real game production calendar still needs its own source-status remediation and tests.

See P0 issue #105 and PR #106 for the original evidence, and the earlier v96 report for the affected weeks.
