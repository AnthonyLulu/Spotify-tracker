# ATP frozen 1 Dec 2025 Top200: measured stage readiness

Verified on the **isolated E2E Supabase project**, 10 October 2026.
This is a read-only audit and explicitly **not a 2050 certification**.

The repository's `court-boss/data/atp-singles-2025-12-01.json`
contains 200 player references with their ranks and points. Its
source/provenance and redistribution licence must still be checked
before using it as an official/commercial historical ranking.

### Direct stage result

| Measured field | Count |
|---|---:|
| Frozen reference rows | 200 |
| Direct imported ATP stage profile, correct rank/points | 189 |
| Matching name in older NCAA/university data, identity not verified | 8 |
| Matching name of a **generated** player, unsafe to merge | 1 |
| No matching name anywhere in stage | 2 |
| Mismatches between internal game-world rank and frozen ATP rank | 198 |
| Historic 2025 tournament-level points rows | 0 |
| Synthetic aggregate reconciliation rows | 2,021 |

Missing from the stage name inventory:
`Yunchaokete Bu` (frozen #122) and `Daniel Merida` (#165).

The one **generated homonym** is `Gabriel Diallo` (#41), whose
synthetic instance has an inappropriate country assignment: this
name collision must **never** be upgraded to a real player by
name-only matching. The eight historical ITA/NCAA name matches
also require player-ID and provenance checks before reuse.
Among the 189 directly imported ATP records, rank and
points mismatches are both zero. For example, imported
Alcaraz holds *reference* #1 with 12,050 points, but is
*internal game-world* #5,376; Sinner is ATP reference #2,
11,500 points, internal world #5,377.

The original 85-table E2E archive checkpoint is deliberately
left unchanged. Correct live 2025 initialisation requires an
authorized isolated seed plan, not rewriting these archived
fixture records, inventing point breakdowns, or silently moving
ATP/NCAA/generated identities.

`atp-top200-reference-gate-2025-v55.sql` is a fail-closed
read-only report that explicitly checks source ranks, game ranks,
provenance, generated homonym risk and tournament-level
52-week history. The gate is currently **RED**, as expected.

Related: #10, #18, #54, merged PRs #52 and #53.
