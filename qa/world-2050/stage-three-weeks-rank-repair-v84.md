# Mandatory rank repair in every completed isolated world-singles week (v84)

Real staging week one 4–11 January and week two 11–18 January
completed 15/15 and 14/14 ATP/Challenger/ITF singles tournaments.
Rank updates after two weeks caused 2,037 duplicate global ATP/depth
positions, repaired with existing `refresh_game_world_ranks()`
inside a verified stage-only commit, without changing any of 2,197
official ATP positions. All weeks' strict receipts green.

Week three 18–25 January completed 11/11 further tournaments and
341 additional scored main-draw matches, but created **3 new rank
collisions** after ATP refresh. Re-running stage-only v81 forced
rollback and v83 commit repaired all 3, leaving **2,200 official
ATP ranks unchanged** and the third week strict receipt green.

The rank repair must thus be part of the **weekly completion
transaction**, not a one-off. This v84 SQL changes only the private
`cb_e2e_reconstruction_20261010.step_world_week_v2` test helper
to call `refresh_game_world_ranks()` immediately after
`refresh_world_rankings`, require nested world rank integrity and
exact official ATP/game rank identity before marking a job complete.
An exception rolls back the whole week's finalization rather than
persisting a false-success marker.

This is stage-only QA, not a production migration. It must be tested
on a subsequent actual week's persisted matches and ranks before
the production Edge/backend pipeline can adopt an analogous fix.

CAVEATS: Only ATP/Challenger/ITF singles, no full NCAA, Davis, doubles,
juniors, managed Match Center, save/load, authentic 2025 historical
event-level ATP data, and no 2050 career certification yet.
