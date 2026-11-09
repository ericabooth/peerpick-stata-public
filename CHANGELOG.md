# Changelog

All notable changes to peerpick. Dates are the day the work landed locally.

## 0.1.2 — 2026-11-09

Fixes.

- `peerpick spec`, `placebo`, and `stability` no longer drop a documented
  abbreviation when they replay the last call. In 0.1.1 any prefix of two
  or more letters matched an option being replaced, so `gr(border)` (the
  help's abbreviation of `group()`) was stripped as if it were `graph`,
  and the replays after `method(pscore)` failed with r(198). Each option
  is now matched against its own minimum abbreviation.
- When `distance(mahalanobis)` falls back to the standardized Euclidean
  distance (no more candidates than factors), `r(distance)` now says
  `euclidean` and `r(note)`, shown in the output, says why. Before, the
  fallback was silent and `r(distance)` said `mahalanobis`.
- An empty candidate pool (for example, a dataset holding only the focal
  unit) now exits with error 2001 and a message instead of a Mata
  conformability error.
- The examples do-file and the test files now run from the flat folder
  that `net get peerpick` fills as well as from a repo clone. Before,
  they looked only in `../data` and stopped with r(601) after `net get`.
- Help: the last example saves to the current folder (it named a
  `build/` folder that need not exist), and the Lawson and Hanson
  reference renders its title in italics instead of showing raw braces.
- `tests/build_testdata.do` quotes its temporary file, so it runs when
  the temporary folder path has a space.
- New checks in `tests/test03_regressions.do`.

## 0.1.1 — 2026-11-09

Fixes.

- The `graph` option no longer empties the stored results. In 0.1.0
  `graph dot` cleared `r()` before it was returned, so `r(gap)`,
  `r(peers)`, `r(balance)`, and the rest were missing after any call with
  `graph`.
- `method(cem)` with `strata()` and no factors now keeps the whole
  stratum, as the help says, and ignores `k()`. In 0.1.0 it kept an
  arbitrary 10 units of the stratum, chosen by the sort order.
- Candidates tied at the same distance are now taken in order of the id
  in every method that keeps the k nearest, so results no longer depend on
  the sort order or the Stata version. Untied results are unchanged.
- String ids that contain spaces (county names, for example) now stay
  whole: `r(peers)` quotes each id, and `peerpick stability` and the
  Jaccard overlap in `peerpick spec` work on whole ids. In 0.1.0
  `stability` split such ids into words, excluded nothing, and reported
  perfect stability.
- New `tests/test03_regressions.do` covers each fix.

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
