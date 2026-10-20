* test01_methods.do -- every peerpick method on real data, with checks
* Run from the tests/ folder.  Stops at the first failing assert.
version 16
clear all
set more off
adopath ++ "`c(pwd)'/../src"
local data "`c(pwd)'/../data"
capture log close
log using test01_methods.log, replace text

* ----------------------------------------------------------------------
* A. nearest neighbours on the county cross-section
* ----------------------------------------------------------------------
use "`data'/tx_counties.dta", clear
describe, short

* A1. Mahalanobis, k = 10, metro stratum, Webb County (the deck's example)
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) strata(metro) k(10) outcome(unins)
local p1 `"`r(peers)'"'
local gap_maha = r(gap)
assert r(k) == 10
assert "`r(method)'" == "knn"
assert r(N_pool) > 50
assert abs(r(gap) - (r(focal_y) - r(peer_y))) < 1e-9
assert r(focal_y) == 36.2
count if pp_peer == 1
assert r(N) == 10
count if pp_peer == 2
assert r(N) == 1
* peers all share the focal's stratum
assert metro == 1 if pp_peer == 1
* the peer list in r() matches the flags
levelsof fips5 if pp_peer == 1, local(p2) clean
assert `"`p1'"' == `"`p2'"'
* weights sum to one
summ pp_w if pp_peer == 1
assert abs(r(sum) - 1) < 1e-9
* ranks are 1..10 in distance order
sort pp_rank
assert pp_dist[_n] >= pp_dist[_n-1] if pp_rank > 1 & pp_rank < .
sort fips5
* the sort order came back intact
assert fips5[1] == "48001"
list county_name pov hisp metro unins pp_dist pp_rank if inlist(pp_peer, 1, 2), noobs sep(0)

* A2. the same with a name instead of a code
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(Webb) ///
    name(county_name) strata(metro) k(10) outcome(unins) replace
assert `"`r(focal)'"' == "48479"
assert `"`r(peers)'"' == `"`p1'"'

* A3. standardized Euclidean with weights; interval and effective n
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) strata(metro) k(10) outcome(unins) ///
    distance(euclidean) weights(2 1 2 1 1 1 1) replace
assert "`r(distance)'" == "euclidean"
assert r(k) == 10
assert abs(r(ess) - 10) < 1e-9
assert r(lb) < r(gap) & r(gap) < r(ub)
assert r(se) > 0

* A4. caliper: fewer than k
peerpick pov lpop hisp, id(fips5) focal(48479) k(10) caliper(1.5) replace distance(euclidean)
assert r(k) <= 10
assert pp_dist <= 1.5 if pp_peer == 1
* an impossible caliper is an error, not an empty set
capture noisily peerpick pov lpop hisp, id(fips5) focal(48479) k(10) caliper(0.01) replace distance(euclidean)
assert _rc == 2000
di as txt "note from the run: `r(note)'"

* A5. no strata, numeric id
gen long fips = real(fips5)
peerpick pov lpop hisp medage, id(fips) focal(48479) k(5) outcome(unins) replace
assert r(k) == 5
assert `"`r(focal)'"' == "48479"
drop fips

* A6. generate() stub and nodisplay
peerpick pov lpop hisp, id(fips5) focal(48479) k(5) generate(webb) nodisplay
confirm variable webb_peer webb_w webb_dist webb_rank
drop webb_*

* A7. errors are caught
capture noisily peerpick pov lpop, id(fips5) focal(99999) k(5) replace
assert _rc == 459
capture noisily peerpick pov lpop, id(fips5) focal(48479) k(5) method(bogus) replace
assert _rc == 198
capture noisily peerpick, id(fips5) focal(48479) k(5) replace
assert _rc == 198
capture noisily peerpick pov lpop, id(fips5) focal(48479) k(5) method(typology) replace
assert _rc == 198

* ----------------------------------------------------------------------
* B. coarsened cells
* ----------------------------------------------------------------------
peerpick pov lpop hisp, id(fips5) focal(48479) name(county_name) k(10) ///
    method(cem) bins(3) outcome(unins) replace
assert r(cell_n) >= r(k)
assert r(k) <= 10
list county_name pov lpop hisp unins pp_dist if inlist(pp_peer, 1, 2), noobs sep(0)
* every peer is in the same tercile as Webb on each factor
foreach v in pov lpop hisp {
    xtile b_`v' = `v', nq(3)
    summ b_`v' if pp_peer == 2, meanonly
    assert b_`v' == r(min) if pp_peer == 1
    drop b_`v'
}
* with strata only, cem is the stratum
peerpick, id(fips5) focal(48479) method(cem) strata(metro border) k(100) replace
assert border == 1 & metro == 1 if pp_peer == 1
local kk = r(k)
count if metro == 1 & border == 1 & fips5 != "48479"
assert r(N) == `kk'

* ----------------------------------------------------------------------
* C. typology: the cell is the group
* ----------------------------------------------------------------------
peerpick, id(fips5) focal(48479) method(typology) strata(rucc border) outcome(unins) replace
local ncell = r(cell_n)
count if rucc == 2 & border == 1 & fips5 != "48479"
assert r(N) == `ncell'
count if pp_peer == 1
assert r(N) == `ncell'
* typology with factors: nearest k inside the cell
peerpick pov hisp, id(fips5) focal(48479) method(typology) strata(metro) k(5) outcome(unins) replace
assert r(k) == 5
assert metro == 1 if pp_peer == 1

* ----------------------------------------------------------------------
* D. propensity score: nearest on the logit index among non-border counties
* ----------------------------------------------------------------------
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) method(pscore) group(border) k(10) outcome(unins) replace
assert r(k) == 10
assert border == 0 if pp_peer == 1
assert r(pscore_focal) > 0 & r(pscore_focal) < 1
list county_name hisp pov border unins pp_dist if inlist(pp_peer, 1, 2), noobs sep(0)
* focal must be in group 1
capture noisily peerpick pov lpop hisp, id(fips5) focal(48201) method(pscore) group(border) k(5) replace
assert _rc == 198

* ----------------------------------------------------------------------
* E. predicted value: nearest on the fitted outcome
* ----------------------------------------------------------------------
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) method(predicted) outcome(unins) k(10) replace
assert r(k) == 10
assert r(r2) > 0.3
assert r(focal_fitted) < .
local ff = r(focal_fitted)
* check the fitted values by hand
regress unins pov lpop hisp medage pct65 bach unemp
predict double yh, xb
summ yh if pp_peer == 2, meanonly
local fh = r(mean)
assert abs(`fh' - `ff') < 1e-6
gen double dd = abs(yh - `fh') if fips5 != "48479"
sort dd
gen byte top10 = _n <= 10
assert pp_peer == 1 if top10
assert top10 == 1 if pp_peer == 1
drop yh dd top10
sort fips5

* ----------------------------------------------------------------------
* F. k-means cluster membership
* ----------------------------------------------------------------------
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) method(cluster) nclusters(6) seed(1) outcome(unins) replace
assert r(cluster_n) == r(k)
assert r(k) >= 1
di as txt "cluster holds `r(k)' counties"
* reproducible with the same seed
local set1 `"`r(peers)'"'
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) method(cluster) nclusters(6) seed(1) outcome(unins) replace nodisplay
assert `"`r(peers)'"' == `"`set1'"'

* ----------------------------------------------------------------------
* G. entropy balancing: weighted peer means equal the focal values
* ----------------------------------------------------------------------
peerpick pov lpop hisp medage, id(fips5) focal(48479) name(county_name) ///
    method(entropy) outcome(unins) replace
di as txt "converged = `r(converged)'; max imbalance = `r(maximb)'; ess = `r(ess)'"
if r(converged) == 1 {
    assert r(max_stddiff) < 1e-4
    assert r(ess) < r(k)
}
matrix list r(balance)
local conv = r(converged)
* weights are nonnegative and sum to one
summ pp_w if pp_peer == 1
assert abs(r(sum) - 1) < 1e-9
assert r(min) >= 0
* a focal unit inside the hull balances exactly: Nueces County
peerpick pov lpop hisp medage, id(fips5) focal(48355) name(county_name) ///
    method(entropy) outcome(unins) replace
di as txt "Nueces: converged = `r(converged)'; max imbalance = `r(maximb)'; ess = `r(ess)'"
assert r(converged) == 1
assert r(max_stddiff) < 1e-5
assert r(ess) > 1
assert r(ess) < r(k)
* a focal unit outside the hull cannot be balanced: the largest county
peerpick pov lpop hisp medage, id(fips5) focal(48201) name(county_name) ///
    method(entropy) outcome(unins) replace
di as txt "Harris: converged = `r(converged)'; max imbalance = `r(maximb)'"
assert r(converged) == 0
assert r(maximb) > 0.01

* ----------------------------------------------------------------------
* H. a hand-picked list
* ----------------------------------------------------------------------
peerpick pov lpop hisp, id(fips5) focal(48479) name(county_name) method(list) ///
    peers(48061 48141 48215 48323 48999) outcome(unins) replace
assert r(k) == 4
assert `"`r(peers)'"' == "48061 48141 48215 48323"
list county_name pov lpop hisp unins pp_dist if inlist(pp_peer, 1, 2), noobs sep(0)

* ----------------------------------------------------------------------
* I. graph
* ----------------------------------------------------------------------
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) strata(metro) k(10) outcome(unins) replace graph nodisplay
graph export test01_dot.png, replace width(900)

di as res "test01_methods: all checks passed"
log close
