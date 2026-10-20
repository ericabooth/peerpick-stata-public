* build_testdata.do -- assemble the real-data test files for peerpick
* Sources: ACS 2019-23 + PLACES 2023 + RUCC 2023 (county_features.dta built by
* ../peers_uninsured_county_202610/01_build_features.do); SAIPE county poverty
* 2005-2023 (Census API); FRED annual state unemployment, per-capita income,
* and population (BLS and BEA series via FRED).
version 16
clear all
local root "`c(pwd)'"
local raw  "`root'/../../data/raw"
local out  "`root'/../data"

* ---- 1. county cross-section (copy, trimmed) ---------------------------
use "`root'/../../peers_uninsured_county_202610/build/county_features.dta", clear
keep fips5 county_name unins unins_lo unins_hi pop lpop pov hisp medage pct65 bach unemp rucc metro border
label data "Texas counties: ACS 2019-23 features + PLACES 2023 uninsured"
compress
save "`out'/tx_counties.dta", replace

* ---- 2. county poverty panel from SAIPE ---------------------------------
clear
python:
import json
from sfi import Data
d = json.load(open(r"`raw'/saipe_tx_county_2005_2023.json"))
hdr, rows = d[0], d[1:]
Data.setObsTotal(len(rows))
Data.addVarStr("county_name", 40)
Data.addVarInt("year")
Data.addVarDouble("pov")
Data.addVarDouble("mhi")
Data.addVarStr("fips5", 5)
for i, r in enumerate(rows):
    Data.storeAt("county_name", i, r[0])
    Data.storeAt("pov", i, float(r[1]) if r[1] not in (None, "") else None)
    Data.storeAt("mhi", i, float(r[2]) if r[2] not in (None, "") else None)
    Data.storeAt("year", i, int(r[3]))
    Data.storeAt("fips5", i, r[4] + r[5])
end
label var pov "Poverty rate, all ages, % (SAIPE)"
label var mhi "Median household income, $ (SAIPE)"
replace county_name = subinstr(county_name, " County", "", .)
sort fips5 year
isid fips5 year
label data "Texas counties: SAIPE poverty and income, 2005-2023"
compress
save "`out'/tx_county_panel.dta", replace

* ---- 3. state panel from FRED --------------------------------------------
tempfile acc
local first 1
foreach ser in UR PCPI POP {
    local dir = cond("`ser'"=="UR","fred_state_ur",cond("`ser'"=="PCPI","fred_state_pcpi","fred_state_pop"))
    local files : dir "`raw'/`dir'" files "*.csv"
    foreach f of local files {
        local st = substr("`f'", 1, 2)
        import delimited "`raw'/`dir'/`f'", clear varnames(1) stringcols(1)
        rename observation_date date
        gen int year = real(substr(date, 1, 4))
        rename `=lower("`st'`ser'")' `=lower("`ser'")'
        gen str2 state = "`st'"
        keep state year `=lower("`ser'")'
        if `first' {
            save `acc', replace
            local first 0
        }
        else {
            append using `acc'
            save `acc', replace
        }
    }
}
use `acc', clear
collapse (firstnm) ur pcpi pop, by(state year)
drop if missing(ur) & missing(pcpi) & missing(pop)
label var ur   "Unemployment rate, annual avg % (BLS via FRED)"
label var pcpi "Per capita personal income, $ (BEA via FRED)"
label var pop  "Resident population, thousands (Census via FRED)"
sort state year
isid state year
label data "US states + DC: unemployment, income, population, 2000-2024 (FRED)"
compress
save "`out'/us_states.dta", replace
describe
tab year if state=="TX"
