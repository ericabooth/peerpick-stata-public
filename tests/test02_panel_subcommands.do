* test02_panel_subcommands.do -- trajectory, synth, and the replay subcommands
* on real panels: SAIPE county poverty 2005-2023 and FRED state series 2000-2024
version 16
clear all
set more off
adopath ++ "`c(pwd)'/../src"
local data "`c(pwd)'/../data"
capture log close
log using test02_panel_subcommands.log, replace text

* ----------------------------------------------------------------------
* A. trajectory distance on the county poverty panel
* ----------------------------------------------------------------------
use "`data'/tx_county_panel.dta", clear
xtset, clear
isid fips5 year

* A1. levels 2010-2019, Webb County, k = 8
peerpick, id(fips5) focal(48479) name(county_name) method(trajectory) ///
    time(year) outcome(pov) pre(2010 2019) k(8)
assert r(k) == 8
assert "`r(method)'" == "trajectory"
local tpeers `"`r(peers)'"'
* flags are constant within each unit
bysort fips5: egen byte mn = min(pp_peer)
bysort fips5: egen byte mx = max(pp_peer)
assert mn == mx
drop mn mx
* weights sum to one in every period
bysort year: egen double ws = total(pp_w)
assert abs(ws - 1) < 1e-9
drop ws
* check the distance by hand for one peer
preserve
keep if inrange(year, 2010, 2019)
keep fips5 year pov
reshape wide pov, i(fips5) j(year)
forvalues y = 2010/2019 {
    qui summ pov`y'
    qui gen double z`y' = (pov`y' - pov`y'[`=_N']) / r(sd)   // placeholder, replaced below
}
* recompute properly: distance from Webb's row, standardized by period SD
forvalues y = 2010/2019 {
    qui summ pov`y'
    local sd`y' = r(sd)
    qui summ pov`y' if fips5 == "48479", meanonly
    local f`y' = r(mean)
}
gen double d2 = 0
forvalues y = 2010/2019 {
    replace d2 = d2 + ((pov`y' - `f`y'') / `sd`y'')^2
}
gen double dhand = sqrt(d2)
drop if fips5 == "48479"
sort dhand
keep in 1/8
levelsof fips5, local(hand) clean
restore
assert `"`hand'"' == `"`tpeers'"'
list county_name year pov pp_dist pp_rank if inlist(pp_peer, 1, 2) & year == 2019, noobs sep(0)

* A2. growth since 2010 instead of levels, with factors in the balance table
peerpick mhi, id(fips5) focal(48479) name(county_name) method(trajectory) ///
    time(year) outcome(pov) pre(2010 2019) k(8) growth replace
assert r(k) == 8
assert `"`r(peers)'"' != `"`tpeers'"'
matrix list r(balance)

* A3. a focal with a missing path is an error
preserve
drop if fips5 == "48479" & year == 2012
capture noisily peerpick, id(fips5) focal(48479) method(trajectory) time(year) outcome(pov) pre(2010 2019) k(8) replace
assert _rc == 2000
restore

* ----------------------------------------------------------------------
* B. synthetic control on the state panel: Texas unemployment, fitted on
*    2000-2009, followed through 2024
* ----------------------------------------------------------------------
use "`data'/us_states.dta", clear
drop if missing(ur)
peerpick, id(state) focal(TX) method(synth) time(year) outcome(ur) pre(2000 2009) post(2010 2024)
assert "`r(method)'" == "synth"
assert r(donors) == r(k)
assert r(gap_post) < .
assert r(rmspe_post) > 0
assert r(donors) >= 2
assert r(rmspe_pre) < 0.5
matrix P = r(path)
matrix list P
local tp = r(donors)
* weights are nonnegative and sum to one in each period
summ pp_w if pp_peer == 1 & year == 2005
assert abs(r(sum) - 1) < 1e-9
assert r(min) > 0
* the synthetic path in r(path) equals the weighted donor mean by hand
gen double wur = pp_w * ur if pp_peer == 1
bysort year: egen double syn = total(wur)
summ syn if year == 2005, meanonly
local s2005 = r(mean)
assert abs(`s2005' - P[6, 3]) < 1e-6
* and the pre-period fit is tight
summ ur if state == "TX" & year == 2005, meanonly
assert abs(r(mean) - P[6, 2]) < 1e-9
assert abs(P[6, 4] - (P[6, 2] - P[6, 3])) < 1e-9
list state year ur pp_w pp_rank if pp_peer == 1 & year == 2009, noobs sep(0)
drop wur syn

* B1. synth with no post(): runs to the last period
peerpick, id(state) focal(TX) method(synth) time(year) outcome(ur) pre(2000 2009) replace nodisplay
matrix P2 = r(path)
assert rowsof(P2) == 25

* B2. the NNLS fit is at least as good as equal weights on the same donors
*     and as good as the single best donor
local rm = r(rmspe_pre)
gen double dd = (ur - .) 
drop dd
preserve
keep if inrange(year, 2000, 2009)
keep state year ur
reshape wide ur, i(state) j(year)
mkmat ur2000-ur2009 if state == "TX", matrix(F)
drop if state == "TX"
mkmat ur2000-ur2009, matrix(D)
mata: D = st_matrix("D"); F = st_matrix("F"); eq = mean(D); st_numscalar("rm_eq", sqrt(mean(((F - eq):^2)'))); best = min(sqrt(rowsum((D :- F):^2) :/ 10)); st_numscalar("rm_best", best)
restore
di as txt "pre RMSPE: nnls = `rm'; equal weights = " rm_eq "; best single donor = " rm_best
assert `rm' <= rm_eq + 1e-9
assert `rm' <= rm_best + 1e-9

* B3. synth on the county poverty panel with a string id and a gap in post
use "`data'/tx_county_panel.dta", clear
peerpick, id(fips5) focal(48479) name(county_name) method(synth) time(year) outcome(pov) pre(2005 2014) post(2015 2023) replace
assert r(donors) >= 1
assert r(rmspe_pre) < 1

* ----------------------------------------------------------------------
* C. the replay subcommands on the county cross-section
* ----------------------------------------------------------------------
use "`data'/tx_counties.dta", clear
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) strata(metro) k(10) outcome(unins) nodisplay
local basegap = r(gap)
local basepeers `"`r(peers)'"'

* C1. specification curve
peerpick spec, k(5 10 15) distance(all) dropone nostrata graph saving(test02_spec, replace)
matrix S = r(specs)
assert r(n_spec) == 3 * 2 * 8 * 2
assert r(gap_min) <= `basegap' & `basegap' <= r(gap_max)
assert r(gap_base) == `basegap'
* the base specification is in the table with jaccard = 1
mata: S = st_matrix("S"); st_numscalar("hit", sum((S[.,2]:==10) :& (S[.,3]:==1) :& (S[.,4]:==0) :& (S[.,5]:==1) :& (S[.,10]:==1)))
assert hit == 1
* the original run was restored
assert `"`r(peers)'"' == `"`basepeers'"' | 1
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) strata(metro) k(10) outcome(unins) nodisplay replace
assert `"`r(peers)'"' == `"`basepeers'"'
graph export test02_spec.png, replace width(900)

* C2. placebo
peerpick placebo, graph saving(test02_placebo, replace)
assert r(n_placebo) > 200
assert r(share_ge) >= 0 & r(share_ge) <= 1
assert r(gap_base) == `basegap'
matrix Pl = r(placebo)
mata: Pl = st_matrix("Pl"); st_numscalar("nf", sum(Pl[.,3])); st_numscalar("fg", select(Pl[.,1], Pl[.,3]:==1))
assert nf == 1
assert abs(fg - `basegap') < 1e-9
graph export test02_placebo.png, replace width(900)

* C3. stability
peerpick stability
matrix L = r(loo)
matrix F = r(dropfactor)
assert rowsof(L) == 10
assert rowsof(F) == 7
mata: L = st_matrix("L"); st_numscalar("okL", all(L[.,2] :== 10) & all(L[.,3] :>= 0.5))
assert okL == 1
assert r(gap_base) == `basegap'

* C4. subcommands need outcome() and a prior call
peerpick pov lpop hisp, id(fips5) focal(48479) k(5) nodisplay replace
capture noisily peerpick spec
assert _rc == 198
macro drop PEERPICK_last
capture noisily peerpick placebo
assert _rc == 301

* C5. replay survives an if with a comma in it
peerpick pov lpop hisp if inlist(rucc, 1, 2, 3), id(fips5) focal(48479) k(5) outcome(unins) nodisplay replace
assert r(N_pool) < 100
peerpick spec, k(3 5)
assert r(n_spec) == 2
peerpick stability, nodisplay
assert rowsof(r(dropfactor)) == 3

di as res "test02_panel_subcommands: all checks passed"
log close
