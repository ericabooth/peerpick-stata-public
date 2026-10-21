# peerpick

**Choose a comparison group for one unit, see how well it matches, and check how much the choice mattered.**

`peerpick` builds a comparison group (peers) for one focal unit, whatever the unit is: a county, a city, a school, a hospital, a firm, a region, a country. It works from any dataset with one row per candidate (or one row per candidate and period). Ten methods share one syntax, so the method can change while the rest of the do-file stays put: nearest neighbours by Mahalanobis or standardized Euclidean distance, coarsened cells, typology cells, propensity scores, predicted values, k-means clusters, entropy balancing, a hand-picked list, trajectory distance on a panel, and synthetic-control weights. Every call leaves a flag, a weight, a distance, a rank, a balance table of standardized differences, and the gap on an outcome with an interval.

Three subcommands replay the call with one thing varied at a time: `peerpick spec` (a specification curve over k, distance, factors, and strata), `peerpick placebo` (every unit as the focal in turn), and `peerpick stability` (leave one comparison unit out, drop one factor).

```stata
use tx_counties, clear
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) strata(metro) k(10) outcome(unins)
```

```
peerpick: knn comparison group for 48479 (fips5)
  within strata: metro
  factors: pov lpop hisp medage pct65 bach unemp
  pool: 85 candidate(s); selected: 10

  balance on the factors (std diff = (peer mean - focal) / pool SD)
  ----------------------------------------------------------------
  factor                    focal      peers       pool  std diff
  ----------------------------------------------------------------
  pov                          21       18.8       14.9     -0.34
  lpop                       12.5       12.4        9.9     -0.06
  hisp                       95.1       71.1       35.4     -1.06
  medage                     29.8       33.9       39.9      0.64
  pct65                        10       13.5       18.8      0.59
  bach                       20.9       20.6       21.5     -0.04
  unemp                       5.5       5.69       4.65      0.08
  ----------------------------------------------------------------

  outcome unins: focal =    36.2, peers =      29, gap =    7.16  [95% CI   2.72,   11.6]
```

Then:

```stata
peerpick spec, k(5 10 15) distance(all) dropone nostrata graph
peerpick placebo, graph
peerpick stability
```

## Why

Saying how a unit is doing means comparing it with a group, and three choices go into that group: the **pool** (who is a candidate at all), the **factors** (what "similar" is measured on), and the **method** (how similarity becomes a group). Reports tend to state the first and bury the other two. `peerpick` keeps them separate, prints the balance so the resemblance is visible, and makes the sensitivity checks one line each, so a gap that depends on one factor or one comparison unit is caught before it is published.

## Install

```stata
net install peerpick, from("https://raw.githubusercontent.com/ericabooth/peerpick-stata-public/main/") replace
net get peerpick, from("https://raw.githubusercontent.com/ericabooth/peerpick-stata-public/main/")
help peerpick
```

`net get` fetches the three example datasets, the examples do-file, and the test battery. From a local copy of this folder, `net install peerpick, from("/path/to/peerpick")` does the same. Base Stata and Mata, no dependencies; Stata 16 or later.

## Methods

| `method()` | Group | Needs |
|---|---|---|
| `knn` (default) | the k nearest on the factors; Mahalanobis or standardized Euclidean, optional strata and caliper | factors |
| `cem` | the focal unit's cell after cutting each factor into quantile bins, then the k nearest inside it | factors or strata |
| `typology` | every unit in the focal unit's stratum | `strata()` |
| `pscore` | the k units in group 0 nearest the focal unit on a logit index of group membership | factors, `group()` |
| `predicted` | the k units whose fitted outcome is nearest the focal unit's fitted outcome | factors, `outcome()` |
| `cluster` | every other member of the focal unit's k-means cluster | factors |
| `entropy` | weights on every candidate so the weighted factor means equal the focal values | factors |
| `list` | a group given by hand, with the same balance table and checks | `peers()` |
| `trajectory` | the k units whose outcome path over a window is nearest, in levels or growth | `time()`, `outcome()`, `pre()` |
| `synth` | nonnegative donor weights summing to one, fitted to the pre-window outcome path | `time()`, `outcome()`, `pre()` |

The help file describes each one, what it is for, and what it returns.

## The simulator

[Open the simulator](https://ericabooth.github.io/peerpick-stata-public/simulator/peer_simulator.html) to make the same three choices by hand and watch the result. Pick a unit type, a question, and a method; then move the settings (focal unit, factors, k, strata, caliper, and the method's own dials) and see the comparison group, the gap, the balance, and the sensitivity change, with notes and references that follow the settings. Each chart has a "How to read" button, and "Pin this setup" builds a comparison table across setups. Counties use the real data in this package; the other unit types are simulated for teaching. Deep links such as `#county/benchmark/knn` open a scenario directly.

The page is one file, `simulator/peer_simulator.html`, with the fonts, the data, and all code inline. It runs offline from any folder, so it can be copied to a shared drive or opened from `net get peerpick`. `simulator/build_simulator.py` rebuilds it from the template and `county_data.csv`.

## Example data

Three real datasets ship with the package so the examples and the tests run as written:

- `tx_counties.dta`: 254 Texas counties. Uninsured adults 18-64 from CDC PLACES (2023 release), poverty, population, share Hispanic, median age, share 65+, bachelor's share, and unemployment from the ACS 2019-23 five-year estimates, and the 2023 USDA rural-urban continuum code with metro and border flags.
- `tx_county_panel.dta`: the SAIPE poverty rate and median household income for Texas counties, 2005-2023.
- `us_states.dta`: annual unemployment (BLS), per capita personal income (BEA), and population (Census) for the 50 states and DC, 2000-2024, via FRED.

`tests/build_testdata.do` rebuilds them from the raw downloads.

## Tests

```stata
cd tests
do runall.do
```

`test01_methods.do` runs every method on the county cross-section and checks the results against hand computations (distances, fitted values, cell membership, weight sums, convex-hull behaviour of the entropy weights, error codes). `test02_panel_subcommands.do` does the same for the two panel methods (the trajectory distance by hand, the synthetic-control fit against equal weights and the best single donor) and for the three subcommands. Both stop at the first failing `assert`.

## Files

```
peerpick/
  src/peerpick.ado        the command, its helpers, and the Mata routines
  src/peerpick.sthlp      help
  data/                   example datasets
  examples/               the help-file examples as a do-file
  simulator/              the in-browser simulator (built page, template, data, build script)
  tests/                  test battery and the data builder
  peerpick.pkg, stata.toc package files for net install
  CHANGELOG.md, LICENSE
```

## License

MIT. See `LICENSE`.
