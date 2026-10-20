* peerpick_examples.do -- the examples from help peerpick, runnable as a script
*
* Run from the folder that holds the example data (after -net get peerpick-,
* that is the current folder), or set the global below to the data folder.
*
*   do peerpick_examples.do
version 16
clear all
set more off
if "$peerpick_data" == "" global peerpick_data "`c(pwd)'/../data"
local data "$peerpick_data"

* ---- nearest neighbours within the same metro status -------------------
use "`data'/tx_counties.dta", clear
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) strata(metro) k(10) outcome(unins)
list county_name pov hisp unins pp_dist pp_rank if inlist(pp_peer, 1, 2), noobs

* the same by name, with a graph
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(Webb) ///
    name(county_name) strata(metro) k(10) outcome(unins) graph replace

* standardized Euclidean distance, two factors counted double, and a caliper
peerpick pov lpop hisp medage, id(fips5) focal(48479) name(county_name) ///
    distance(euclidean) weights(2 1 2 1) caliper(2) k(10) outcome(unins) replace

* ---- coarsened cells ---------------------------------------------------
peerpick pov lpop hisp, id(fips5) focal(48479) name(county_name) ///
    method(cem) bins(3) k(10) outcome(unins) replace

* ---- a typology: same rural-urban code and border status ---------------
peerpick, id(fips5) focal(48479) name(county_name) method(typology) ///
    strata(rucc border) outcome(unins) replace

* ---- propensity score: non-border counties that look like a border county
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) method(pscore) group(border) k(10) outcome(unins) replace

* ---- predicted value: counties with the same expected uninsured rate ----
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) method(predicted) outcome(unins) k(10) replace
display "focal residual " r(focal_resid) ", peer mean residual " r(peer_resid)

* ---- cluster membership ------------------------------------------------
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) method(cluster) nclusters(6) outcome(unins) replace

* ---- entropy balancing -------------------------------------------------
peerpick pov lpop hisp medage, id(fips5) focal(48355) name(county_name) ///
    method(entropy) outcome(unins) replace
display "converged " r(converged) ", effective n " r(ess)

* ---- a hand-picked list, given the same checks --------------------------
peerpick pov lpop hisp, id(fips5) focal(48479) name(county_name) method(list) ///
    peers(48061 48141 48215 48323) outcome(unins) replace

* ---- the checks --------------------------------------------------------
peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) ///
    name(county_name) strata(metro) k(10) outcome(unins) replace nodisplay
peerpick spec, k(5 10 15) distance(all) dropone nostrata graph
peerpick placebo, graph
peerpick stability

* ---- trajectory on the county poverty panel -----------------------------
use "`data'/tx_county_panel.dta", clear
peerpick, id(fips5) focal(48479) name(county_name) method(trajectory) ///
    time(year) outcome(pov) pre(2010 2019) k(8)
peerpick, id(fips5) focal(48479) name(county_name) method(trajectory) ///
    time(year) outcome(pov) pre(2010 2019) k(8) growth replace

* ---- synthetic control on the state panel ------------------------------
use "`data'/us_states.dta", clear
peerpick, id(state) focal(TX) method(synth) time(year) outcome(ur) ///
    pre(2000 2009) post(2010 2024)
matrix list r(path)
list state year ur pp_w if pp_peer == 1 & year == 2009, noobs
