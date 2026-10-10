# Court Boss ATP points projection V57

This lightweight browser module recomputes the already-loaded ATP event
portfolio, before and after the next expiring week. It does **not** require
an extra API request or the unversioned production Edge source.

Verified SQL tests in the isolated project:
- 330 ATP 500 final points expire with no reserve: net −330.
- 330 expire but a previously non-counting 100 moves into the best
  eighteen slots: net −230.

The forecast is conditional and labels its hypothesis: no new scores
until the chosen cutoff. It refuses to display any number when its
current tally differs from the authoritative ranking ledger response.

Neither this JS forecast nor its CI tests certify the historical
2025 tournament-level point ledger or the 2025–2050 real simulation.
No production SQL write or user save migration accompanies this PR.
