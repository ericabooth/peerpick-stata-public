# Changelog

All notable changes to peerpick. Dates are the day the work landed locally.

## 0.1.0 — 2026-10-20

First release.

- Ten methods behind one syntax: `knn` (Mahalanobis or standardized
  Euclidean, with strata, caliper, and factor weights), `cem`, `typology`,
  `pscore`, `predicted`, `cluster`, `entropy`, `list`, `trajectory`, and
  `synth`.
- Every call leaves `pp_peer`, `pp_w`, `pp_dist`, `pp_rank`, a balance table
  of standardized differences, and the outcome gap with a t interval on the
  effective number of comparison units.
- `peerpick spec`, `peerpick placebo`, and `peerpick stability` replay the
  last call to check the choice.
- Synthetic-control weights solved by Lawson-Hanson nonnegative least
  squares with a sum-to-one constraint; entropy balancing by Newton's method
  on the dual, reporting the remaining imbalance when the focal unit lies
  outside the convex hull.
- `simulator/peer_simulator.html`: an offline, single-file companion page
  for making the same three choices by hand (unit, question, method) and
  watching the group, the gap, the balance, and the sensitivity change.
  Template, data, fonts, and build script included.
- Test battery on real data: Texas counties (ACS 2019-23, PLACES 2023,
  RUCC 2023), the SAIPE county poverty panel 2005-2023, and FRED state
  unemployment, income, and population 2000-2024.
