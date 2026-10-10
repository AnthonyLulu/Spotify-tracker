# Stage-only rank repair, P0 #79

The first completed actual singles world week has 15/15 tournament
simulations and 461 main-draw matches, but is not certified because
2,031 `game_world_rank` positions collide between current ATP-ranked
players and depth-only synthetic junior profiles. Existing
`refresh_game_world_ranks()` is designed to move collisions to the
tail without changing official ATP `ranking`. Direct read-only
evidence: **2,120 official-ranked players, 2,120 unique official ATP
rankings, 0 official game-rank mismatches** before repair.

This new isolated QA function must refuse while a weekly job has
status `running`, while a save/career exists, or when an advisory lock
cannot be acquired. If stage is idle, it runs the *actual existing*
repair twice, measures duplicate counts after each, verifies official
ranking hash is unchanged and 0 retired/unranked player drift, then
forces a nested PL/pgSQL exception that rolls back all modifications.

**A compiled function alone is NOT repair certification.** Require a
measured `ok=true, rolled_back=true` receipt before considering a
non-destructive weekly integration of the repair. The 2025 ATP
Top200/per-event historical source and full 2050 simulation remain
independent red gates. No production changes.
