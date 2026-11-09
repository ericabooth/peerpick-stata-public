* test03_regressions.do -- checks for the bugs fixed in 0.1.1 and 0.1.2
* Run from the tests/ folder (or the folder -net get peerpick- filled).
* Stops at the first failing assert.
version 16
clear all
set more off
* repo clone: run from tests/, next to src/ and data/.  After -net get
* peerpick- the data sit flat in the current folder and peerpick is the
* installed copy, so use whichever layout is present.
mata: st_local("havesrc", strofreal(direxists("`c(pwd)'/../src")))
if `havesrc' adopath ++ "`c(pwd)'/../src"
local data "`c(pwd)'/../data"
capture confirm file "`data'/tx_counties.dta"
if _rc local data "`c(pwd)'"
capture log close
log using test03_regressions.log, replace text

* ----------------------------------------------------------------------
* A. the graph option keeps r()
* ----------------------------------------------------------------------
use "`data'/tx_counties.dta", clear
peerpick pov lpop hisp, id(fips5) focal(48479) strata(metro) k(10) ///
    outcome(unins) nodisplay
local gap0 = r(gap)
local peers0 `"`r(peers)'"'
matrix B0 = r(balance)
peerpick pov lpop hisp, id(fips5) focal(48479) strata(metro) k(10) ///
    outcome(unins) nodisplay replace graph
assert r(gap) == `gap0'
assert `"`r(peers)'"' == `"`peers0'"'
assert r(k) == 10
assert mreldif(r(balance), B0) == 0
* the help example: by name, with a graph
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(Webb) ///
    name(county_name) strata(metro) k(10) outcome(unins) graph replace
assert r(k) == 10 & !missing(r(gap))
graph drop _all

* ----------------------------------------------------------------------
* B. cem with strata() and no factors is the whole stratum, whatever the
*    sort order, and agrees with typology
* ----------------------------------------------------------------------
peerpick, id(fips5) focal(48479) method(typology) strata(metro) ///
    outcome(unins) nodisplay replace
local tgap = r(gap)
local tk = r(k)
peerpick, id(fips5) focal(48479) method(cem) strata(metro) ///
    outcome(unins) nodisplay replace
assert r(k) == r(cell_n)
assert r(k) == `tk'
assert reldif(r(gap), `tgap') < 1e-12
set seed 7
generate double u = runiform()
sort u
peerpick, id(fips5) focal(48479) method(cem) strata(metro) ///
    outcome(unins) nodisplay replace
assert r(k) == `tk'
assert reldif(r(gap), `tgap') < 1e-12
drop u

* ----------------------------------------------------------------------
* C. ties at the k-th distance are broken by id, not by the sort order
* ----------------------------------------------------------------------
use "`data'/tx_counties.dta", clear
generate byte bin = floor(pov / 5)
peerpick bin, id(fips5) focal(48479) k(10) outcome(unins) nodisplay
local tp `"`r(peers)'"'
local tg = r(gap)
forvalues s = 1/3 {
    set seed `s'
    generate double u = runiform()
    sort u
    peerpick bin, id(fips5) focal(48479) k(10) outcome(unins) ///
        nodisplay replace
    assert `"`r(peers)'"' == `"`tp'"'
    assert r(gap) == `tg'
    drop u
}

* ----------------------------------------------------------------------
* D. string ids with spaces stay whole
* ----------------------------------------------------------------------
use "`data'/tx_counties.dta", clear
isid county_name
peerpick pov lpop hisp medage, id(fips5) focal(48479) strata(metro) k(5) ///
    outcome(unins) nodisplay
local ngap = r(gap)
peerpick stability, nodisplay
matrix Ln = r(loo)
peerpick spec, k(3 5 8) nodisplay
matrix Sn = r(specs)

peerpick pov lpop hisp medage, id(county_name) focal(Webb County) ///
    strata(metro) k(5) outcome(unins) nodisplay replace
assert r(gap) == `ngap'
local sp `"`r(peers)'"'
assert `: word count `sp'' == 5
assert `: list posof "Cameron County" in sp' > 0
peerpick stability, nodisplay
matrix Ls = r(loo)
assert rowsof(Ls) == 5
assert mreldif(Ls, Ln) < 1e-12
peerpick spec, k(3 5 8) nodisplay
assert mreldif(r(specs), Sn) < 1e-12
* r(peers) feeds method(list)
peerpick pov lpop hisp medage, id(county_name) focal(Webb County) ///
    method(list) peers(`sp') outcome(unins) nodisplay replace
assert r(k) == 5
assert r(gap) == `ngap'
* ids without spaces still come back unquoted
peerpick pov lpop hisp medage, id(fips5) focal(48479) strata(metro) k(5) ///
    outcome(unins) nodisplay replace
assert strpos(`"`r(peers)'"', `"""') == 0

* ----------------------------------------------------------------------
* F. (0.1.2) replay keeps a documented abbreviation: gr() is group()
* ----------------------------------------------------------------------
use "`data'/tx_counties.dta", clear
peerpick pov lpop hisp medage, id(fips5) focal(48479) method(pscore) ///
    gr(border) k(10) outcome(unins) nodisplay
local gpa = r(gap)
peerpick stability, nodisplay
assert r(gap_base) == `gpa'
peerpick spec, k(5 10) nodisplay
assert rowsof(r(specs)) >= 2
* the long form gives the same base gap
peerpick pov lpop hisp medage, id(fips5) focal(48479) method(pscore) ///
    group(border) k(10) outcome(unins) nodisplay replace
assert r(gap) == `gpa'

* ----------------------------------------------------------------------
* G. (0.1.2) the Mahalanobis-to-Euclidean fallback is reported
* ----------------------------------------------------------------------
use "`data'/tx_counties.dta", clear
peerpick pov lpop hisp medage pct65 bach unemp if _n <= 6 | fips5 == "48479", ///
    id(fips5) focal(48479) k(3) outcome(unins) nodisplay replace
assert "`r(distance)'" == "euclidean"
assert strpos(`"`r(note)'"', "Euclidean distance was used") > 0
local gfb = r(gap)
peerpick pov lpop hisp medage pct65 bach unemp if _n <= 6 | fips5 == "48479", ///
    id(fips5) focal(48479) k(3) outcome(unins) distance(euclidean) nodisplay replace
assert r(gap) == `gfb'
* with enough candidates Mahalanobis is used and no note is added
peerpick pov lpop hisp, id(fips5) focal(48479) k(5) outcome(unins) nodisplay replace
assert "`r(distance)'" == "mahalanobis"
assert strpos(`"`r(note)'"', "Euclidean distance was used") == 0

* ----------------------------------------------------------------------
* H. (0.1.2) an empty candidate pool is a clean error, not a Mata error
* ----------------------------------------------------------------------
clear
set obs 1
gen id = 1
gen x = 1
capture noisily peerpick x, id(id) focal(1)
assert _rc == 2001

di as res "test03_regressions: all checks passed"
log close
