*! version 0.1.0  20oct2026  Eric Booth
*! peerpick: choose a comparison group for one unit and check how much the
*! choice matters.  Nearest neighbours (Mahalanobis or standardized Euclidean),
*! coarsened cells, typology cells, propensity scores, predicted values,
*! k-means clusters, trajectory distance, synthetic-control weights, entropy
*! balancing, or a hand-picked list; then balance, specification curves,
*! placebo gaps, and leave-one-out stability.

program define peerpick, rclass
    version 16

    * ---- subcommand dispatch -------------------------------------------
    gettoken sub rest : 0, parse(" ,")
    if inlist(`"`sub'"', "spec", "placebo", "stability") {
        local 0 `"`rest'"'
        _pp_`sub' `0'
        return add
        exit
    }

    * ---- main call ------------------------------------------------------
    local cmdline `"`0'"'
    syntax [varlist(default=none numeric)] [if] [in], ID(varname) FOCal(string) ///
        [Method(string) K(integer 10) DISTance(string) STRata(varlist) ///
         CALiper(real -1) Weights(numlist >0) OUTcome(varname numeric) ///
         NAme(varname string) BINs(integer 4) GRoup(varname numeric) ///
         NCLusters(integer 5) SEED(integer 20361) TIme(varname numeric) ///
         PRE(numlist min=2 max=2 sort) POST(numlist min=2 max=2 sort) GROWth ///
         PEERS(string asis) GENerate(name) REPLACE noDISPlay LEVel(cilevel) ///
         TOLerance(real 1e-8) ITERate(integer 500) GRAPH SAVing(string asis) ///
         EXCLude(string asis) DROPFactor(varname)]

    * remember the call so the subcommands can replay it
    global PEERPICK_last `"`cmdline'"'

    _pp_core `cmdline'
    if "`display'" == "" _pp_show
    if "`graph'" != "" _pp_graph, saving(`saving')
    return add
end


* =====================================================================
* _pp_core : parse, select, compute; leaves everything in r()
* =====================================================================
program define _pp_core, rclass
    version 16
    syntax [varlist(default=none numeric)] [if] [in], ID(varname) FOCal(string) ///
        [Method(string) K(integer 10) DISTance(string) STRata(varlist) ///
         CALiper(real -1) Weights(numlist >0) OUTcome(varname numeric) ///
         NAme(varname string) BINs(integer 4) GRoup(varname numeric) ///
         NCLusters(integer 5) SEED(integer 20361) TIme(varname numeric) ///
         PRE(numlist min=2 max=2 sort) POST(numlist min=2 max=2 sort) GROWth ///
         PEERS(string asis) GENerate(name) REPLACE noDISPlay LEVel(cilevel) ///
         TOLerance(real 1e-8) ITERate(integer 500) GRAPH SAVing(string asis) ///
         EXCLude(string asis) DROPFactor(varname)]

    local factors `varlist'
    if "`dropfactor'" != "" {
        local factors : list factors - dropfactor
    }
    if "`generate'" == "" local generate pp
    if "`method'" == "" local method knn
    local method = lower("`method'")
    local okm knn cem typology pscore predicted cluster trajectory synth entropy list
    if !`: list method in okm' {
        di as err "method(`method') not recognized; choose one of: `okm'"
        exit 198
    }
    if "`distance'" == "" local distance mahalanobis
    local distance = lower("`distance'")
    if !inlist("`distance'", "mahalanobis", "euclidean") {
        di as err "distance() must be mahalanobis or euclidean"
        exit 198
    }
    if `k' < 1 {
        di as err "k() must be at least 1"
        exit 198
    }

    * requirements by method
    if inlist("`method'", "knn", "pscore", "predicted", "cluster", "entropy") & "`factors'" == "" {
        di as err "method(`method') needs a list of factors (the varlist)"
        exit 198
    }
    if "`method'" == "cem" & "`factors'" == "" & "`strata'" == "" {
        di as err "method(cem) needs factors to coarsen, strata(), or both"
        exit 198
    }
    if "`method'" == "typology" & "`strata'" == "" {
        di as err "method(typology) needs strata(): the cell is the comparison group"
        exit 198
    }
    if "`method'" == "pscore" & "`group'" == "" {
        di as err "method(pscore) needs group(varname): a 0/1 variable with the focal unit in group 1"
        exit 198
    }
    if "`method'" == "predicted" & "`outcome'" == "" {
        di as err "method(predicted) needs outcome()"
        exit 198
    }
    if inlist("`method'", "trajectory", "synth") {
        if "`time'" == "" | "`outcome'" == "" | "`pre'" == "" {
            di as err "method(`method') needs time(), outcome(), and pre(start end)"
            exit 198
        }
    }
    if "`method'" == "list" & `"`peers'"' == "" {
        di as err "method(list) needs peers(): the ids of the comparison units"
        exit 198
    }

    * ---- panel or cross-section? ---------------------------------------
    local panel = ("`time'" != "")
    if `panel' {
        capture isid `id' `time'
        if _rc {
            di as err "`id' and `time' do not uniquely identify observations"
            exit 459
        }
    }
    else {
        capture isid `id'
        if _rc {
            di as err "`id' does not uniquely identify observations; for panel data add time()"
            exit 459
        }
    }

    * ---- working sample ----------------------------------------------
    tempvar ord
    qui gen long `ord' = _n
    marksample touse, novarlist
    markout `touse' `factors' `strata', strok
    if "`group'" != ""   markout `touse' `group'
    if "`outcome'" != "" & !`panel' markout `touse' `outcome'
    if `panel' markout `touse' `time'

    * drop excluded ids (used by the stability subcommand)
    local idstr = (substr("`: type `id''", 1, 3) == "str")
    if `"`exclude'"' != "" {
        foreach x of local exclude {
            if `idstr' qui replace `touse' = 0 if `id' == `"`x'"'
            else       qui replace `touse' = 0 if `id' == `x'
        }
    }

    * ---- find the focal unit ------------------------------------------
    tempvar isfocal
    qui gen byte `isfocal' = 0
    if `idstr' qui replace `isfocal' = 1 if `id' == `"`focal'"' & `touse'
    else {
        capture confirm number `focal'
        if _rc {
            * maybe a value label or a name() match
            if "`name'" != "" {
                qui replace `isfocal' = 1 if lower(`name') == lower(`"`focal'"') & `touse'
            }
        }
        else qui replace `isfocal' = 1 if `id' == `focal' & `touse'
    }
    if "`name'" != "" {
        qui count if `isfocal'
        if r(N) == 0 qui replace `isfocal' = 1 if lower(`name') == lower(`"`focal'"') & `touse'
        qui count if `isfocal'
        if r(N) == 0 {
            * a unique partial match on the name will do ("Webb" for "Webb County")
            qui count if strpos(lower(`name'), lower(`"`focal'"')) > 0 & `touse'
            if r(N) == 1 qui replace `isfocal' = 1 if strpos(lower(`name'), lower(`"`focal'"')) > 0 & `touse'
            else if r(N) > 1 {
                di as err `"focal("`focal'") matches `r(N)' values of `name'; give the full name or the `id' code"'
                exit 459
            }
        }
    }
    qui count if `isfocal'
    if r(N) == 0 {
        di as err `"focal unit "`focal'" not found in `id'"' _c
        if "`name'" != "" di as err " or `name'"
        else di as err ""
        exit 459
    }
    * the id value of the focal, as text
    if `idstr' {
        qui levelsof `id' if `isfocal', local(focalid) clean
    }
    else {
        qui summ `id' if `isfocal', meanonly
        local focalid = r(min)
    }

    * ---- strata: candidates must match the focal on each -----------------
    tempvar cand
    qui gen byte `cand' = `touse'
    if "`strata'" != "" {
        foreach s of local strata {
            if substr("`: type `s''", 1, 3) == "str" {
                qui levelsof `s' if `isfocal', local(sv) clean
                qui replace `cand' = 0 if `s' != `"`sv'"'
            }
            else {
                qui summ `s' if `isfocal', meanonly
                qui replace `cand' = 0 if `s' != r(min)
            }
        }
    }
    qui replace `cand' = 0 if `isfocal'

    * ---- generated variables ------------------------------------------
    foreach v in peer w dist rank {
        capture confirm variable `generate'_`v'
        if !_rc {
            if "`replace'" == "" {
                di as err "`generate'_`v' already exists; use replace or generate()"
                exit 110
            }
            drop `generate'_`v'
        }
    }
    qui gen byte   `generate'_peer = 0 if `touse'
    qui gen double `generate'_w    = 0 if `touse'
    qui gen double `generate'_dist = .
    qui gen int    `generate'_rank = .
    label var `generate'_peer "peerpick: 1 = comparison unit, 2 = focal"
    label var `generate'_w    "peerpick: comparison weight (sums to 1)"
    label var `generate'_dist "peerpick: distance from the focal unit"
    label var `generate'_rank "peerpick: rank by distance"
    qui replace `generate'_peer = 2 if `isfocal'

    * ---- dispatch -------------------------------------------------------
    local note ""
    local nfac : word count `factors'
    if "`weights'" != "" {
        local nw : word count `weights'
        if `nw' != `nfac' {
            di as err "weights() needs one weight per factor (`nfac')"
            exit 198
        }
    }
    else {
        local weights ""
        forvalues j = 1/`nfac' {
            local weights `weights' 1
        }
    }

    if "`method'" == "knn"        _pp_knn        `factors', id(`id') cand(`cand') focal(`isfocal') gen(`generate') k(`k') distance(`distance') caliper(`caliper') weights(`weights')
    if "`method'" == "cem"        _pp_cem        `factors', id(`id') cand(`cand') focal(`isfocal') gen(`generate') k(`k') bins(`bins') distance(`distance') weights(`weights')
    if "`method'" == "typology"   _pp_typology   `factors', id(`id') cand(`cand') focal(`isfocal') gen(`generate') k(`k') distance(`distance') weights(`weights')
    if "`method'" == "pscore"     _pp_pscore     `factors', id(`id') cand(`cand') focal(`isfocal') gen(`generate') k(`k') group(`group') caliper(`caliper') touse(`touse')
    if "`method'" == "predicted"  _pp_predicted  `factors', id(`id') cand(`cand') focal(`isfocal') gen(`generate') k(`k') outcome(`outcome') touse(`touse')
    if "`method'" == "cluster"    _pp_cluster    `factors', id(`id') cand(`cand') focal(`isfocal') gen(`generate') nclusters(`nclusters') seed(`seed') touse(`touse')
    if "`method'" == "entropy"    _pp_entropy    `factors', id(`id') cand(`cand') focal(`isfocal') gen(`generate') tolerance(`tolerance') iterate(`iterate')
    if "`method'" == "list"       _pp_list,                  id(`id') cand(`cand') focal(`isfocal') gen(`generate') peers(`peers') factors(`factors') distance(`distance') weights(`weights')
    if "`method'" == "trajectory" _pp_trajectory `factors', id(`id') cand(`cand') focal(`isfocal') gen(`generate') k(`k') time(`time') outcome(`outcome') pre(`pre') `growth' weights(`weights')
    if "`method'" == "synth"      _pp_synth      `factors', id(`id') cand(`cand') focal(`isfocal') gen(`generate') time(`time') outcome(`outcome') pre(`pre') post(`post') tolerance(`tolerance') iterate(`iterate')
    local note `"`r(note)'"'
    local extra_scalars `r(extra_scalars)'
    foreach s of local extra_scalars {
        local v_`s' = r(`s')
    }
    tempname pathmat
    if "`method'" == "synth" matrix `pathmat' = r(path)

    * ---- collect the peer set -----------------------------------------
    qui count if `generate'_peer == 1
    local npeers = r(N)
    if `npeers' == 0 {
        di as err "no comparison units selected; loosen the caliper, strata, or bins"
        exit 2000
    }
    * one row per unit (in a panel, the first period)
    tempvar one
    if `panel' {
        bysort `id' (`time'): gen byte `one' = (_n == 1)
    }
    else qui gen byte `one' = 1
    qui count if `generate'_peer == 1 & `one'
    local npeers = r(N)

    * weights sum to one over peer units (so over each period in a panel)
    qui summ `generate'_w if `generate'_peer == 1 & `one', meanonly
    if r(sum) > 0 qui replace `generate'_w = `generate'_w / r(sum) if `generate'_peer == 1
    else          qui replace `generate'_w = 1 / `npeers' if `generate'_peer == 1
    qui replace `generate'_w = . if `generate'_peer != 1
    qui replace `generate'_rank = . if `generate'_peer != 1
    local peerlist ""
    qui levelsof `id' if `generate'_peer == 1 & `one', local(peerlist) clean

    * ---- outcome gap --------------------------------------------------
    local haveY = ("`outcome'" != "")
    if `haveY' & !`panel' {
        qui summ `outcome' if `isfocal', meanonly
        local fy = r(mean)
        qui summ `outcome' [aw = `generate'_w] if `generate'_peer == 1
        local py  = r(mean)
        local psd = r(sd)
        local gap = `fy' - `py'
        * SE of the peer mean: sd / sqrt(effective n)
        tempname W
        tempvar sel
        qui gen byte `sel' = (`generate'_peer == 1)
        mata: st_numscalar("`W'", _pp_ess(st_data(., "`generate'_w", "`sel'")))
        local ess = `W'
        if `npeers' > 1 & `psd' < . {
            local se = `psd' / sqrt(`ess')
            local tcrit = invttail(max(`ess' - 1, 1), (100 - `level') / 200)
            local lb = `gap' - `tcrit' * `se'
            local ub = `gap' + `tcrit' * `se'
        }
        else {
            local se = .
            local lb = .
            local ub = .
        }
    }
    else if `haveY' & `panel' {
        * last pre period level and, if post() given, mean post gap
        tokenize `pre'
        local p0 `1'
        local p1 `2'
        qui summ `outcome' if `isfocal' & `time' == `p1', meanonly
        local fy = r(mean)
        qui summ `outcome' [aw = `generate'_w] if `generate'_peer == 1 & `time' == `p1', meanonly
        local py = r(mean)
        local gap = `fy' - `py'
        local se = .
        local lb = .
        local ub = .
        local psd = .
        tempname W
        tempvar sel
        qui gen byte `sel' = (`generate'_peer == 1 & `time' == `p1')
        mata: st_numscalar("`W'", _pp_ess(st_data(., "`generate'_w", "`sel'")))
        local ess = `W'
    }
    else {
        local fy = .
        local py = .
        local gap = .
        local se = .
        local lb = .
        local ub = .
        local psd = .
        tempname W
        tempvar sel
        qui gen byte `sel' = (`generate'_peer == 1 & `one' == 1)
        mata: st_numscalar("`W'", _pp_ess(st_data(., "`generate'_w", "`sel'")))
        local ess = `W'
    }

    * ---- balance table on the factors (and strata if numeric) -----------
    tempname B
    local brows ""
    if `nfac' > 0 {
        matrix `B' = J(`nfac', 4, .)
        local j 0
        foreach v of local factors {
            local ++j
            if `panel' {
                qui summ `v' if `isfocal' & `time' == `p1', meanonly
                local f = r(mean)
                qui summ `v' [aw = `generate'_w] if `generate'_peer == 1 & `time' == `p1'
                local pm = r(mean)
                qui summ `v' if `touse' & `time' == `p1'
            }
            else {
                qui summ `v' if `isfocal', meanonly
                local f = r(mean)
                qui summ `v' [aw = `generate'_w] if `generate'_peer == 1
                local pm = r(mean)
                qui summ `v' if `touse'
            }
            local poolm = r(mean)
            local poolsd = r(sd)
            matrix `B'[`j', 1] = `f'
            matrix `B'[`j', 2] = `pm'
            matrix `B'[`j', 3] = `poolm'
            matrix `B'[`j', 4] = cond(`poolsd' > 0, (`pm' - `f') / `poolsd', .)
            local brows `brows' `v'
        }
        matrix rownames `B' = `brows'
        matrix colnames `B' = focal peers pool stddiff
    }

    * ---- pool size ------------------------------------------------------
    qui count if `cand' & `one'
    local npool = r(N)

    * ---- store ------------------------------------------------------------
    return local  cmdline   `"peerpick `0'"'
    return local  method    "`method'"
    return local  distance  "`distance'"
    return local  factors   "`factors'"
    return local  strata    "`strata'"
    return local  id        "`id'"
    return local  outcome   "`outcome'"
    return local  focal     `"`focalid'"'
    return local  peers     `"`peerlist'"'
    return local  generate  "`generate'"
    return local  name      "`name'"
    return local  note      `"`note'"'
    return scalar k         = `npeers'
    return scalar N_pool    = `npool'
    return scalar ess       = `ess'
    return scalar focal_y   = `fy'
    return scalar peer_y    = `py'
    return scalar peer_sd   = `psd'
    return scalar gap       = `gap'
    return scalar se        = `se'
    return scalar lb        = `lb'
    return scalar ub        = `ub'
    return scalar level     = `level'
    if `panel' return scalar gap_time = `p1'
    if `nfac' > 0 {
        mata: st_numscalar("`W'", max(abs(st_matrix("`B'")[., 4])))
        return scalar max_stddiff = `W'
        return matrix balance = `B'
    }
    sort `ord'
    foreach s of local extra_scalars {
        return scalar `s' = `v_`s''
    }
    if "`method'" == "synth" return matrix path = `pathmat'
end


* =====================================================================
* methods : each sets gen_peer = 1, gen_w, gen_dist, gen_rank on the
*           chosen units and may return r(note) and extra r() scalars
* =====================================================================

* ---- nearest neighbours -------------------------------------------
program define _pp_knn, rclass
    version 16
    syntax varlist(numeric), id(varname) cand(varname) focal(varname) gen(name) ///
        k(integer) distance(string) caliper(real) weights(numlist)
    tempvar d
    qui gen double `d' = .
    mata: _pp_distvar("`varlist'", "`cand'", "`focal'", "`d'", "`distance'", "`weights'")
    _pp_takek `d', cand(`cand') gen(`gen') k(`k') caliper(`caliper')
    return local note `"`r(note)'"'
end

* ---- coarsened exact cells, then nearest within the cell -------------
program define _pp_cem, rclass
    version 16
    syntax [varlist(numeric default=none)], id(varname) cand(varname) focal(varname) gen(name) ///
        k(integer) bins(integer) distance(string) [weights(numlist)]
    tempvar cell d
    qui gen byte `cell' = `cand' | `focal'
    * cut each factor into quantile bins over the pool + focal; keep the focal's bin
    foreach v of local varlist {
        tempvar b
        qui xtile `b' = `v' if `cand' | `focal', nq(`bins')
        qui summ `b' if `focal', meanonly
        qui replace `cell' = 0 if `b' != r(min)
    }
    qui replace `cell' = 0 if `focal'
    qui count if `cell'
    local ncell = r(N)
    if `ncell' == 0 {
        di as err "the focal unit's coarsened cell is empty; use fewer bins() or fewer factors"
        exit 2000
    }
    qui gen double `d' = .
    if "`varlist'" != "" {
        mata: _pp_distvar("`varlist'", "`cell'", "`focal'", "`d'", "`distance'", "`weights'")
    }
    else qui replace `d' = 0 if `cell'
    _pp_takek `d', cand(`cell') gen(`gen') k(`k') caliper(-1)
    return local note "coarsened cell holds `ncell' candidate(s) on `bins' bins per factor"
    return scalar cell_n = `ncell'
    return local extra_scalars cell_n
end

* ---- typology: the stratum is the comparison group ---------------------
program define _pp_typology, rclass
    version 16
    syntax [varlist(numeric default=none)], id(varname) cand(varname) focal(varname) gen(name) ///
        k(integer) distance(string) [weights(numlist)]
    tempvar d
    qui gen double `d' = .
    if "`varlist'" != "" {
        mata: _pp_distvar("`varlist'", "`cand'", "`focal'", "`d'", "`distance'", "`weights'")
    }
    else qui replace `d' = 0 if `cand'
    qui count if `cand'
    local ncell = r(N)
    * every member of the cell is a peer; k() only applies when factors are given
    if "`varlist'" != "" _pp_takek `d', cand(`cand') gen(`gen') k(`k') caliper(-1)
    else                 _pp_takek `d', cand(`cand') gen(`gen') k(`ncell') caliper(-1)
    return local note "typology cell holds `ncell' candidate(s)"
    return scalar cell_n = `ncell'
    return local extra_scalars cell_n
end

* ---- propensity score: nearest on the logit index among group == 0 ----
program define _pp_pscore, rclass
    version 16
    syntax varlist(numeric), id(varname) cand(varname) focal(varname) gen(name) ///
        k(integer) group(varname) caliper(real) touse(varname)
    qui summ `group' if `focal', meanonly
    if r(min) != 1 {
        di as err "the focal unit must have `group' == 1"
        exit 198
    }
    capture assert inlist(`group', 0, 1) if `touse'
    if _rc {
        di as err "`group' must be 0/1"
        exit 198
    }
    tempvar xb d
    capture qui logit `group' `varlist' if `touse', iterate(50)
    if _rc {
        di as err "logit of `group' on the factors failed (r(`=_rc'))"
        exit _rc
    }
    qui predict double `xb' if `touse', xb
    qui summ `xb' if `focal', meanonly
    local fxb = r(mean)
    qui summ `xb' if `touse'
    local sdxb = r(sd)
    qui gen double `d' = abs(`xb' - `fxb') / `sdxb' if `cand' & `group' == 0
    _pp_takek `d', cand(`cand') gen(`gen') k(`k') caliper(`caliper')
    return local note "distance = |logit index - focal index| in SD units; peers drawn from `group' == 0"
    return scalar pscore_focal = invlogit(`fxb')
    return local extra_scalars pscore_focal
end

* ---- predicted value: nearest on the fitted outcome ---------------------
program define _pp_predicted, rclass
    version 16
    syntax varlist(numeric), id(varname) cand(varname) focal(varname) gen(name) ///
        k(integer) outcome(varname) touse(varname)
    tempvar yhat d res
    qui regress `outcome' `varlist' if `touse'
    local r2 = e(r2)
    qui predict double `yhat' if `touse', xb
    qui predict double `res'  if `touse', residuals
    qui summ `yhat' if `focal', meanonly
    local fhat = r(mean)
    qui summ `res' if `focal', meanonly
    local fres = r(mean)
    qui gen double `d' = abs(`yhat' - `fhat') if `cand'
    _pp_takek `d', cand(`cand') gen(`gen') k(`k') caliper(-1)
    qui summ `res' if `gen'_peer == 1, meanonly
    return local note "distance = |fitted outcome - focal fitted|; regression R2 = `: di %5.3f `r2''"
    return scalar r2           = `r2'
    return scalar focal_fitted = `fhat'
    return scalar focal_resid  = `fres'
    return scalar peer_resid   = r(mean)
    return local extra_scalars r2 focal_fitted focal_resid peer_resid
end

* ---- k-means cluster membership ------------------------------------------
program define _pp_cluster, rclass
    version 16
    syntax varlist(numeric), id(varname) cand(varname) focal(varname) gen(name) ///
        nclusters(integer) seed(integer) touse(varname)
    tempvar d grp
    local zs ""
    foreach v of local varlist {
        tempvar z
        qui summ `v' if `cand' | `focal'
        qui gen double `z' = (`v' - r(mean)) / r(sd) if `cand' | `focal'
        local zs `zs' `z'
    }
    tempname cl
    qui cluster kmeans `zs' if `cand' | `focal', k(`nclusters') start(krandom(`seed')) name(`cl') generate(`grp')
    qui summ `grp' if `focal', meanonly
    local fg = r(min)
    tempvar incl
    qui gen byte `incl' = `cand' & `grp' == `fg'
    qui count if `incl'
    local n = r(N)
    if `n' == 0 {
        di as err "the focal unit is alone in its cluster; use fewer nclusters()"
        exit 2000
    }
    qui gen double `d' = .
    local w ""
    foreach v of local varlist {
        local w `w' 1
    }
    mata: _pp_distvar("`varlist'", "`incl'", "`focal'", "`d'", "euclidean", "`w'")
    _pp_takek `d', cand(`incl') gen(`gen') k(`n') caliper(-1)
    cluster drop `cl'
    return local note "focal unit is in cluster `fg' of `nclusters' (k-means on standardized factors, seed `seed'); all members are peers"
    return scalar cluster_n = `n'
    return local extra_scalars cluster_n
end

* ---- entropy balancing: weights so the peer means equal the focal values --
program define _pp_entropy, rclass
    version 16
    syntax varlist(numeric), id(varname) cand(varname) focal(varname) gen(name) ///
        tolerance(real) iterate(integer)
    tempname conv maximb
    mata: _pp_ebal_run("`varlist'", "`cand'", "`focal'", "`gen'", `tolerance', `iterate', "`conv'", "`maximb'")
    qui count if `gen'_peer == 1
    local n = r(N)
    if `conv' == 1 local note "entropy weights converged; weighted peer means match the focal unit (max |std diff| = `: di %6.4f `maximb'')"
    else local note "entropy weights did not converge: the focal unit is probably outside the convex hull of the pool (max |std diff| = `: di %6.4f `maximb'')"
    return local note "`note'"
    return scalar converged = `conv'
    return scalar maximb    = `maximb'
    return local extra_scalars converged maximb
end

* ---- a hand-picked list ------------------------------------------------
program define _pp_list, rclass
    version 16
    syntax, id(varname) cand(varname) focal(varname) gen(name) peers(string asis) ///
        [factors(varlist) distance(string) weights(numlist)]
    local idstr = (substr("`: type `id''", 1, 3) == "str")
    tempvar incl d
    qui gen byte `incl' = 0
    local missing ""
    foreach p of local peers {
        if `idstr' qui count if `id' == `"`p'"' & `cand'
        else       qui count if `id' == `p' & `cand'
        if r(N) == 0 local missing `"`missing' `p'"'
        if `idstr' qui replace `incl' = 1 if `id' == `"`p'"' & `cand'
        else       qui replace `incl' = 1 if `id' == `p' & `cand'
    }
    if `"`missing'"' != "" di as txt "note: not in the pool and ignored:`missing'"
    qui gen double `d' = .
    if "`factors'" != "" {
        mata: _pp_distvar("`factors'", "`incl'", "`focal'", "`d'", "`distance'", "`weights'")
    }
    else qui replace `d' = 0 if `incl'
    qui count if `incl'
    _pp_takek `d', cand(`incl') gen(`gen') k(`=r(N)') caliper(-1)
    return local note "comparison units supplied by hand"
end

* ---- trajectory: distance on the outcome path over the pre window ---------
program define _pp_trajectory, rclass
    version 16
    syntax [varlist(numeric default=none)], id(varname) cand(varname) focal(varname) gen(name) ///
        k(integer) time(varname) outcome(varname) pre(numlist) [growth weights(numlist)]
    tokenize `pre'
    local p0 `1'
    local p1 `2'
    tempvar d
    qui gen double `d' = .
    mata: _pp_traj("`id'", "`time'", "`outcome'", "`cand'", "`focal'", `p0', `p1', "`growth'" != "", "`d'")
    * d is filled on every row of a unit; takek works on one row per unit
    tempvar one dd
    bysort `id' (`time'): gen byte `one' = (_n == 1)
    qui gen double `dd' = `d' if `one' & `cand'
    _pp_takek `dd', cand(`cand') gen(`gen') k(`k') caliper(-1)
    * spread the flags to every row of the unit
    foreach v in peer w dist rank {
        bysort `id' (`one'): replace `gen'_`v' = `gen'_`v'[_N] if `cand'
    }
    local what = cond("`growth'" != "", "change since `p0'", "level")
    return local note "distance = Euclidean on the `what' of `outcome' at each period `p0'-`p1', standardized by period"
end

* ---- synthetic control: nonnegative weights summing to one -----------------
program define _pp_synth, rclass
    version 16
    syntax [varlist(numeric default=none)], id(varname) cand(varname) focal(varname) gen(name) ///
        time(varname) outcome(varname) pre(numlist) [post(numlist)] tolerance(real) iterate(integer)
    tokenize `pre'
    local p0 `1'
    local p1 `2'
    if "`post'" != "" {
        tokenize `post'
        local q0 `1'
        local q1 `2'
    }
    else {
        qui summ `time' if `cand' | `focal', meanonly
        local q0 = `p1' + 1
        local q1 = r(max)
        if `q0' > `q1' local q1 = `q0'
    }
    tempname rmspe path
    mata: _pp_synth_run("`id'", "`time'", "`outcome'", "`varlist'", "`cand'", "`focal'", `p0', `p1', `q0', `q1', "`gen'", `tolerance', `iterate', "`rmspe'", "`path'")
    tempvar one
    bysort `id' (`time'): gen byte `one' = (_n == 1)
    qui count if `gen'_peer == 1 & `one'
    local n = r(N)
    * mean gap and RMSPE over the post window
    tempname gpost rpost
    mata: _pp_postgap("`path'", `p1', "`gpost'", "`rpost'")
    return local note "nonnegative weights summing to one fitted on `outcome' `p0'-`p1'; `n' donor(s) with positive weight; pre-period RMSPE = `: di %8.4g `rmspe''"
    return scalar rmspe_pre = `rmspe'
    return scalar rmspe_post = `rpost'
    return scalar gap_post  = `gpost'
    return scalar donors    = `n'
    return local extra_scalars rmspe_pre rmspe_post gap_post donors
    return matrix path = `path'
end

* ---- shared: keep the k nearest candidates by a distance variable ---------
program define _pp_takek, rclass
    version 16
    syntax varname, cand(varname) gen(name) k(integer) caliper(real)
    tempvar r
    qui gen double `r' = `varlist' if `cand' & `varlist' < .
    if `caliper' >= 0 qui replace `r' = . if `r' > `caliper'
    sort `r'
    qui gen long `gen'_rank_tmp = _n if `r' < .
    qui replace `gen'_peer = 1 if `gen'_rank_tmp <= `k' & `r' < .
    qui replace `gen'_w    = 1 if `gen'_peer == 1
    qui replace `gen'_dist = `r' if `gen'_peer == 1
    qui replace `gen'_rank = `gen'_rank_tmp if `gen'_peer == 1
    drop `gen'_rank_tmp
    qui count if `gen'_peer == 1
    local n = r(N)
    if `caliper' >= 0 & `n' < `k' return local note "caliper(`caliper') left `n' of the `k' requested"
end


* =====================================================================
* display and graph
* =====================================================================
program define _pp_show
    version 16
    local method   `r(method)'
    local focal    `"`r(focal)'"'
    local gen      `r(generate)'
    local id       `r(id)'
    local outcome  `r(outcome)'
    local factors  `r(factors)'
    local strata   `r(strata)'
    local k        = r(k)
    local npool    = r(N_pool)
    local note     `"`r(note)'"'
    tempname B
    local haveB = ("`factors'" != "")
    if `haveB' matrix `B' = r(balance)
    local gaptime = r(gap_time)
    local gpost = r(gap_post)
    local rpost = r(rmspe_post)
    local gap  = r(gap)
    local fy   = r(focal_y)
    local py   = r(peer_y)
    local se   = r(se)
    local lb   = r(lb)
    local ub   = r(ub)
    local ess  = r(ess)
    local lev  = r(level)

    di
    di as txt "peerpick: " as res "`method'" as txt " comparison group for " as res `"`focal'"' as txt " (`id')"
    if "`strata'" != "" di as txt "  within strata: " as res "`strata'"
    if "`factors'" != "" di as txt "  factors: " as res "`factors'"
    if `"`note'"' != "" di as txt "  `note'"
    di as txt "  pool: " as res `npool' as txt " candidate(s); selected: " as res `k' _c
    if abs(`ess' - `k') > 1e-6 di as txt " (effective n = " as res %6.1f `ess' as txt ")"
    else di

    * balance table
    if `haveB' {
        di
        di as txt "  balance on the factors (std diff = (peer mean - focal) / pool SD)"
        di as txt "  {hline 64}"
        di as txt "  " %-20s "factor" %11s "focal" %11s "peers" %11s "pool" %10s "std diff"
        di as txt "  {hline 64}"
        local rn : rownames `B'
        local i 0
        foreach v of local rn {
            local ++i
            di as txt "  " %-20s abbrev("`v'", 20) as res %11.3g `B'[`i',1] %11.3g `B'[`i',2] %11.3g `B'[`i',3] %10.2f `B'[`i',4]
        }
        di as txt "  {hline 64}"
    }

    * outcome gap
    if "`outcome'" != "" & `fy' < . {
        di
        if `gaptime' < . di as txt "  outcome " as res "`outcome'" as txt " at " as res `gaptime' as txt ": focal = " _c
        else di as txt "  outcome " as res "`outcome'" as txt ": focal = " _c
        di as res %7.3g `fy' as txt ", peers = " as res %7.3g `py' as txt ", gap = " as res %7.3g `gap' _c
        if `se' < . di as txt "  [`lev'% CI " as res %6.3g `lb' as txt ", " as res %6.3g `ub' as txt "]"
        else di
        if `gpost' < . di as txt "  post-period: mean gap = " as res %7.3g `gpost' as txt ", RMSPE = " as res %7.3g `rpost' as txt "; path in r(path)"
    }
    di
    di as txt "  comparison units are flagged in " as res "`gen'_peer" as txt " (weights in " as res "`gen'_w" as txt "); ids in r(peers)"
    di
end

program define _pp_graph
    version 16
    syntax [, saving(string asis)]
    local gen     `r(generate)'
    local id      `r(id)'
    local outcome `r(outcome)'
    local focal   `"`r(focal)'"'
    local name    `r(name)'
    if "`outcome'" == "" {
        di as txt "graph needs outcome()"
        exit
    }
    local py = r(peer_y)
    tempvar lab yp yf
    local idstr = (substr("`: type `id''", 1, 3) == "str")
    if "`name'" != ""  qui gen str `lab' = `name' if inlist(`gen'_peer, 1, 2)
    else if `idstr'    qui gen str `lab' = `id' if inlist(`gen'_peer, 1, 2)
    else               qui gen str `lab' = string(`id') if inlist(`gen'_peer, 1, 2)
    qui gen double `yp' = `outcome' if `gen'_peer == 1
    qui gen double `yf' = `outcome' if `gen'_peer == 2
    label var `yp' "comparison units"
    label var `yf' "focal unit"
    local sv ""
    if `"`saving'"' != "" local sv saving(`saving')
    graph dot (asis) `yp' `yf' if inlist(`gen'_peer, 1, 2), over(`lab', sort(`outcome') descending label(labsize(small))) ///
        marker(1, msymbol(O) mcolor("12 85 165")) marker(2, msymbol(D) msize(medlarge) mcolor("242 104 82")) ///
        yline(`py', lpattern(dash) lcolor("242 104 82")) ///
        ytitle("`outcome'") title("`focal' and its comparison group", size(medsmall)) ///
        legend(order(2 1) rows(1) size(small)) ///
        note("dashed line: weighted peer mean", size(vsmall)) `sv'
end


* =====================================================================
* subcommands : spec, placebo, stability.  All replay the last call.
* =====================================================================
program define _pp_replay, sclass
    * returns the stored command line in s(cmd)
    version 16
    sreturn clear
    if `"$PEERPICK_last"' == "" {
        di as err "run peerpick first; the subcommands replay the last call"
        exit 301
    }
    * replay with replace and nodisplay, whatever the original call had
    _pp_rebuild, cmd(`"$PEERPICK_last"') drop(replace nodisplay graph saving) add(replace nodisplay)
end

* strip an option (and its argument) from a command line, then append new ones
program define _pp_rebuild, sclass
    version 16
    syntax, cmd(string) [drop(string) add(string)]
    local 0 `"`cmd'"'
    syntax [anything] [if] [in], [*]
    local lhs `"`anything' `if' `in'"'
    * tokenise options respecting parentheses
    local kept ""
    local rest `"`options'"'
    while `"`rest'"' != "" {
        gettoken tok rest : rest, bind
        local tname = lower(`"`tok'"')
        if strpos("`tname'", "(") > 0 local tname = substr("`tname'", 1, strpos("`tname'", "(") - 1)
        local hit 0
        foreach d of local drop {
            if "`tname'" == "`d'" local hit 1
            else if length("`tname'") >= 2 & substr("`d'", 1, length("`tname'")) == "`tname'" local hit 1
        }
        if !`hit' local kept `"`kept' `tok'"'
    }
    sreturn local cmd `"`lhs', `kept' `add'"'
end

* ---- specification curve ----------------------------------------------
program define _pp_spec, rclass
    version 16
    syntax [, K(numlist integer >0) DISTance(string) DROPone noSTRata GRAPH SAVing(string asis) noDISPlay]
    _pp_replay
    local base `"`s(cmd)'"'
    qui _pp_core `base'
    local method `r(method)'
    local factors `r(factors)'
    local basegap = r(gap)
    local basek   = r(k)
    local basedist `r(distance)'
    local basepeers `"`r(peers)'"'
    local outcome `r(outcome)'
    local gen `r(generate)'
    if "`outcome'" == "" {
        di as err "the specification curve needs outcome() in the peerpick call"
        exit 198
    }
    if "`k'" == "" local k `basek'
    if "`distance'" == "" local dists `basedist'
    else if "`distance'" == "all" local dists mahalanobis euclidean
    else local dists `distance'
    local drops "none"
    if "`dropone'" != "" local drops `drops' `factors'
    local stratas keep
    if "`strata'" != "" local stratas keep none

    tempname S
    local nspec 0
    local labels ""
    foreach kk of local k {
        foreach dd of local dists {
            foreach df of local drops {
                foreach st of local stratas {
                    local adds `"k(`kk') distance(`dd') generate(`gen') replace nodisplay"'
                    local dropopts k distance generate replace nodisplay graph saving
                    if "`df'" != "none" local adds `"`adds' dropfactor(`df')"'
                    if "`st'" == "none" local dropopts `dropopts' strata
                    _pp_rebuild, cmd(`"`base'"') drop(`dropopts') add(`adds')
                    capture qui _pp_core `s(cmd)'
                    if _rc continue
                    local ++nspec
                    * Jaccard with the base peer set
                    local cur `"`r(peers)'"'
                    local inter : list basepeers & cur
                    local union : list basepeers | cur
                    local jac = `: word count `inter'' / max(`: word count `union'', 1)
                    matrix `S' = nullmat(`S') \ (`nspec', `kk', ("`dd'" == "mahalanobis"), ("`df'" != "none"), ("`st'" == "keep"), r(k), r(gap), r(lb), r(ub), `jac')
                    local lab "k=`kk' `=substr("`dd'",1,4)'"
                    if "`df'" != "none" local lab "`lab' -`df'"
                    if "`st'" == "none" local lab "`lab' nostrata"
                    local labels `"`labels' "`lab'""'
                }
            }
        }
    }
    * restore the base run so the generated variables match the original call
    qui _pp_core `base'
    matrix colnames `S' = spec k mahalanobis dropped strata npeers gap lb ub jaccard
    mata: st_local("gmin", strofreal(min(st_matrix("`S'")[.,7]))); mata: st_local("gmax", strofreal(max(st_matrix("`S'")[.,7])))
    if "`display'" == "" {
        di
        di as txt "peerpick spec: " as res `nspec' as txt " specification(s); base gap = " as res %7.3g `basegap'
        di as txt "  {hline 70}"
        di as txt "  " %-26s "specification" %7s "peers" %10s "gap" %18s "interval" %9s "jaccard"
        di as txt "  {hline 70}"
        forvalues i = 1/`nspec' {
            local lab : word `i' of `labels'
            di as txt "  " %-26s "`lab'" as res %7.0f `S'[`i',6] %10.3g `S'[`i',7] ///
               "  [" %7.3g `S'[`i',8] ", " %7.3g `S'[`i',9] "]" %9.2f `S'[`i',10]
        }
        di as txt "  {hline 70}"
        di as txt "  gap ranges from " as res %7.3g `gmin' as txt " to " as res %7.3g `gmax' as txt " across specifications"
        di
    }
    if "`graph'" != "" {
        preserve
        qui clear
        qui svmat `S', names(col)
        qui gen double lo = min(lb, gap)
        qui gen double hi = max(ub, gap)
        sort gap
        qui gen int order = _n
        local sv ""
        if `"`saving'"' != "" local sv saving(`saving')
        twoway (rcap lo hi order, lcolor("190 190 190")) ///
               (scatter gap order, msymbol(O) mcolor("12 85 165")), ///
            yline(`basegap', lpattern(dash) lcolor("242 104 82")) yline(0, lcolor(gs10)) ///
            xtitle("specification, sorted by gap") ytitle("focal minus peers") legend(off) ///
            title("Specification curve", size(medsmall)) note("dashed: gap in the base call", size(vsmall)) `sv'
        restore
    }
    return matrix specs = `S'
    return scalar n_spec = `nspec'
    return scalar gap_min = `gmin'
    return scalar gap_max = `gmax'
    return scalar gap_base = `basegap'
end

* ---- placebo: every pool unit as the focal --------------------------------
program define _pp_placebo, rclass
    version 16
    syntax [, GRAPH SAVing(string asis) noDISPlay]
    _pp_replay
    local base `"`s(cmd)'"'
    qui _pp_core `base'
    local id `r(id)'
    local gen `r(generate)'
    local outcome `r(outcome)'
    local basegap = r(gap)
    local focal `"`r(focal)'"'
    if "`outcome'" == "" {
        di as err "placebo needs outcome() in the peerpick call"
        exit 198
    }
    local idstr = (substr("`: type `id''", 1, 3) == "str")
    * the pool: every candidate, in the base run, plus the focal
    tempvar pool
    qui gen byte `pool' = `gen'_peer < .
    if `idstr' qui levelsof `id' if `pool', local(units)
    else       qui levelsof `id' if `pool', local(units) clean
    tempname P
    local n 0
    local nfail 0
    foreach u of local units {
        local uu : subinstr local u `"""' "", all
        _pp_rebuild, cmd(`"`base'"') drop(focal generate replace nodisplay graph saving) add(`"focal(`uu') generate(`gen') replace nodisplay"')
        capture qui _pp_core `s(cmd)'
        if _rc {
            local ++nfail
            continue
        }
        local ++n
        matrix `P' = nullmat(`P') \ (r(gap), r(k), (`"`uu'"' == `"`focal'"'))
    }
    qui _pp_core `base'
    matrix colnames `P' = gap npeers focal
    tempname W
    mata: _pp_placebo_stats("`P'", `basegap', "`W'")
    local share = `W'[1,1]
    local pct   = `W'[1,2]
    if "`display'" == "" {
        di
        di as txt "peerpick placebo: " as res `n' as txt " unit(s) each treated as the focal" _c
        if `nfail' > 0 di as txt " (`nfail' skipped: no comparison group)"
        else di
        di as txt "  focal gap = " as res %7.3g `basegap' as txt "; share of placebo |gaps| at least this large = " as res %5.3f `share'
        di as txt "  the focal gap is at the " as res %4.1f `=100*`pct'' as txt "th percentile of all gaps"
        di
    }
    if "`graph'" != "" {
        preserve
        qui clear
        qui svmat `P', names(col)
        local sv ""
        if `"`saving'"' != "" local sv saving(`saving')
        twoway (histogram gap, color("190 190 190") lcolor(white)), ///
            xline(`basegap', lcolor("242 104 82") lwidth(medthick)) ///
            xtitle("gap when each unit is the focal") ytitle("density") ///
            title("Placebo gaps", size(medsmall)) note("red line: the focal unit", size(vsmall)) `sv'
        restore
    }
    return matrix placebo = `P'
    return scalar n_placebo = `n'
    return scalar share_ge  = `share'
    return scalar pctile    = `pct'
    return scalar gap_base  = `basegap'
end

* ---- stability: drop each peer, drop each factor ---------------------------
program define _pp_stability, rclass
    version 16
    syntax [, noDISPlay]
    _pp_replay
    local base `"`s(cmd)'"'
    qui _pp_core `base'
    local gen `r(generate)'
    local factors `r(factors)'
    local outcome `r(outcome)'
    local basegap = r(gap)
    local basepeers `"`r(peers)'"'
    local id `r(id)'
    local idstr = (substr("`: type `id''", 1, 3) == "str")

    * A. drop each peer from the pool and re-pick
    tempname L
    local n 0
    foreach u of local basepeers {
        local uu : subinstr local u `"""' "", all
        _pp_rebuild, cmd(`"`base'"') drop(exclude generate replace nodisplay graph saving) add(`"exclude(`uu') generate(`gen') replace nodisplay"')
        capture qui _pp_core `s(cmd)'
        if _rc continue
        local ++n
        local cur `"`r(peers)'"'
        local inter : list basepeers & cur
        local union : list basepeers | cur
        matrix `L' = nullmat(`L') \ (r(gap), r(k), `: word count `inter'' / max(`: word count `union'', 1))
    }
    if `n' > 0 matrix colnames `L' = gap npeers jaccard

    * B. drop each factor and re-pick
    tempname F
    local nf 0
    local flabels ""
    foreach v of local factors {
        _pp_rebuild, cmd(`"`base'"') drop(dropfactor generate replace nodisplay graph saving) add(`"dropfactor(`v') generate(`gen') replace nodisplay"')
        capture qui _pp_core `s(cmd)'
        if _rc continue
        local ++nf
        local cur `"`r(peers)'"'
        local inter : list basepeers & cur
        local union : list basepeers | cur
        matrix `F' = nullmat(`F') \ (r(gap), r(k), `: word count `inter'' / max(`: word count `union'', 1))
        local flabels `flabels' `v'
    }
    if `nf' > 0 {
        matrix colnames `F' = gap npeers jaccard
        matrix rownames `F' = `flabels'
    }
    qui _pp_core `base'

    if "`display'" == "" {
        di
        di as txt "peerpick stability: base gap = " as res %7.3g `basegap' as txt " with " as res `: word count `basepeers'' as txt " comparison unit(s)"
        if `n' > 0 {
            mata: st_local("a", strofreal(min(st_matrix("`L'")[.,1]))); mata: st_local("b", strofreal(max(st_matrix("`L'")[.,1])))
            mata: st_local("j", strofreal(mean(st_matrix("`L'")[.,3])))
            di as txt "  A. leave one comparison unit out and re-pick (`n' runs): gap from " as res %7.3g `a' as txt " to " as res %7.3g `b' ///
               as txt "; mean overlap with the base set = " as res %4.2f `j'
        }
        if `nf' > 0 {
            di as txt "  B. drop one factor and re-pick:"
            di as txt "  {hline 52}"
            di as txt "  " %-20s "dropped factor" %8s "peers" %10s "gap" %10s "overlap"
            di as txt "  {hline 52}"
            forvalues i = 1/`nf' {
                local v : word `i' of `flabels'
                di as txt "  " %-20s abbrev("`v'",20) as res %8.0f `F'[`i',2] %10.3g `F'[`i',1] %10.2f `F'[`i',3]
            }
            di as txt "  {hline 52}"
            di as txt "  overlap = Jaccard index of the new comparison set with the base set (1 = identical)"
        }
        di
    }
    if `n' > 0 return matrix loo = `L'
    if `nf' > 0 return matrix dropfactor = `F'
    return scalar gap_base = `basegap'
end


* =====================================================================
* Mata
* =====================================================================
mata:
mata set matastrict on

// effective sample size of a weight vector
real scalar _pp_ess(real colvector w)
{
    if (rows(w) == 0) return(0)
    return((sum(w))^2 / sum(w :^ 2))
}

// fill dvar with the distance of every candidate from the focal unit
void _pp_distvar(string scalar vars, string scalar cand, string scalar focal,
                 string scalar dvar, string scalar type, string scalar wts)
{
    real matrix X, S, Si, D
    real rowvector f, sd, w
    real colvector d, idx
    real scalar p, j

    idx = selectindex(st_data(., cand) :== 1)
    if (rows(idx) == 0) return
    X = st_data(idx, vars)
    f = st_data(selectindex(st_data(., focal) :== 1), vars)
    f = f[1, .]
    p = cols(X)
    w = strtoreal(tokens(wts))
    if (cols(w) != p) w = J(1, p, 1)
    D = X :- f
    if (type == "mahalanobis" & rows(X) > p) {
        S = variance(X \ f)
        Si = invsym(S)
        d = sqrt(rowsum((D * Si) :* D))
    }
    else {
        sd = sqrt(diagonal(variance(X \ f)))'
        for (j = 1; j <= p; j++) if (sd[j] == 0 | sd[j] == .) sd[j] = 1
        d = sqrt(rowsum(((D :/ sd) :^ 2) :* w))
    }
    st_store(idx, dvar, d)
}

// entropy balancing on standardized factor differences
void _pp_ebal_run(string scalar vars, string scalar cand, string scalar focal,
                  string scalar gen, real scalar tol, real scalar maxit,
                  string scalar convname, string scalar imbname)
{
    real matrix X, D, H
    real rowvector f, sd
    real colvector idx, lam, u, pr, g, step, lamn, prn
    real scalar n, p, it, L, Ln, a, j, conv

    idx = selectindex(st_data(., cand) :== 1)
    X = st_data(idx, vars)
    f = st_data(selectindex(st_data(., focal) :== 1), vars)[1, .]
    n = rows(X); p = cols(X)
    sd = sqrt(diagonal(variance(X \ f)))'
    for (j = 1; j <= p; j++) if (sd[j] == 0 | sd[j] == .) sd[j] = 1
    D = (X :- f) :/ sd
    lam = J(p, 1, 0)
    conv = 0
    pr = J(n, 1, 1/n)
    for (it = 1; it <= maxit; it++) {
        u = -D * lam
        pr = exp(u :- max(u)); pr = pr / sum(pr)
        g = D' * pr                       // balance gap; want zero
        if (max(abs(g)) < tol) { conv = 1; break; }
        H = cross(D, pr, D) - g * g'
        step = invsym(H + 1e-10 * I(p)) * g
        L = log(sum(exp(u :- max(u)))) + max(u)
        a = 1
        for (j = 1; j <= 40; j++) {
            lamn = lam + a * step
            Ln = -D * lamn
            Ln = log(sum(exp(Ln :- max(Ln)))) + max(Ln)
            if (Ln < L) break
            a = a / 2
        }
        lam = lamn
    }
    u = -D * lam
    pr = exp(u :- max(u)); pr = pr / sum(pr)
    g = D' * pr
    st_store(idx, gen + "_w", pr)
    st_store(idx, gen + "_peer", J(n, 1, 1))
    st_store(idx, gen + "_dist", sqrt(rowsum(D :^ 2)))
    st_store(idx, gen + "_rank", invorder(order(-pr, 1)))
    st_numscalar(convname, conv)
    st_numscalar(imbname, max(abs(g)))
}

// trajectory distance over a pre window
void _pp_traj(string scalar id, string scalar time, string scalar y,
              string scalar cand, string scalar focal, real scalar p0, real scalar p1,
              real scalar growth, string scalar dvar)
{
    real matrix M, Z
    real colvector t, c, fo, u, yv, d, sel
    string colvector ids, uid
    real scalar T, i, j, k, n
    real rowvector f, sd

    t = st_data(., time); c = st_data(., cand); fo = st_data(., focal); yv = st_data(., y)
    if (st_isstrvar(id)) ids = st_sdata(., id)
    else ids = strofreal(st_data(., id), "%21.0g")
    sel = selectindex((c :== 1 :| fo :== 1) :& t :>= p0 :& t :<= p1)
    uid = uniqrows(ids[sel])
    n = rows(uid); T = p1 - p0 + 1
    M = J(n, T, .)
    u = J(n, 1, 0)                        // 1 if focal
    for (k = 1; k <= rows(sel); k++) {
        i = sel[k]
        j = selectindex(uid :== ids[i])
        M[j, t[i] - p0 + 1] = yv[i]
        if (fo[i] == 1) u[j] = 1
    }
    if (growth) M = M :- M[., 1]
    // drop units with any missing period
    sel = selectindex(rowmissing(M) :== 0)
    M = M[sel, .]; uid = uid[sel]; u = u[sel]
    if (sum(u) == 0) {
        errprintf("the focal unit has no complete outcome path over %g-%g\n", p0, p1)
        exit(2000)
    }
    f = M[selectindex(u :== 1)[1], .]
    sd = sqrt(diagonal(variance(M)))'
    for (j = 1; j <= T; j++) if (sd[j] == 0 | sd[j] == .) sd[j] = 1
    Z = (M :- f) :/ sd
    d = sqrt(rowsum(Z :^ 2))
    // write back to every row of each unit
    for (j = 1; j <= rows(uid); j++) {
        if (u[j] == 1) continue
        st_store(selectindex(ids :== uid[j]), dvar, J(rows(selectindex(ids :== uid[j])), 1, d[j]))
    }
}

// Lawson-Hanson nonnegative least squares
real colvector _pp_nnls(real matrix A, real colvector b, real scalar tol, real scalar maxit)
{
    real scalar n, it, j, jmax, alpha, inner
    real colvector x, w, s, P, idx, ratio
    real matrix Ap

    n = cols(A)
    x = J(n, 1, 0); P = J(n, 1, 0)
    w = A' * (b - A * x)
    it = 0
    while (it++ < maxit) {
        idx = selectindex(P :== 0)
        if (rows(idx) == 0) break
        if (max(w[idx]) <= tol) break
        jmax = idx[selectindex(w[idx] :== max(w[idx]))[1]]
        P[jmax] = 1
        inner = 0
        while (inner++ < maxit) {
            idx = selectindex(P :== 1)
            Ap = A[., idx]
            s = J(n, 1, 0)
            s[idx] = qrsolve(Ap, b)
            if (min(s[idx]) > 0) break
            // step back toward x until a variable hits zero
            ratio = J(n, 1, .)
            for (j = 1; j <= rows(idx); j++) {
                if (s[idx[j]] <= 0) ratio[idx[j]] = x[idx[j]] / (x[idx[j]] - s[idx[j]])
            }
            alpha = min(ratio)
            x = x + alpha * (s - x)
            for (j = 1; j <= n; j++) if (P[j] == 1 & x[j] <= tol) { P[j] = 0; x[j] = 0; }
        }
        x = s
        w = A' * (b - A * x)
    }
    return(x)
}

// synthetic control: weights on donors fitted to the pre-period outcome path
void _pp_synth_run(string scalar id, string scalar time, string scalar y, string scalar vars,
                   string scalar cand, string scalar focal, real scalar p0, real scalar p1,
                   real scalar q0, real scalar q1, string scalar gen, real scalar tol,
                   real scalar maxit, string scalar rmspename, string scalar pathname)
{
    real matrix M, A, path
    real colvector t, c, fo, yv, u, sel, w, b, rows_, idxu
    string colvector ids, uid
    real scalar T, n, i, j, k, v, tt, nd, big, scale
    real rowvector f

    t = st_data(., time); c = st_data(., cand); fo = st_data(., focal); yv = st_data(., y)
    if (st_isstrvar(id)) ids = st_sdata(., id)
    else ids = strofreal(st_data(., id), "%21.0g")
    sel = selectindex((c :== 1 :| fo :== 1) :& t :>= p0 :& t :<= q1)
    uid = uniqrows(ids[sel])
    n = rows(uid); T = q1 - p0 + 1
    M = J(n, T, .); u = J(n, 1, 0)
    for (k = 1; k <= rows(sel); k++) {
        i = sel[k]
        j = selectindex(uid :== ids[i])
        M[j, t[i] - p0 + 1] = yv[i]
        if (fo[i] == 1) u[j] = 1
    }
    // pre-period block must be complete
    sel = selectindex(rowmissing(M[., 1..(p1 - p0 + 1)]) :== 0)
    M = M[sel, .]; uid = uid[sel]; u = u[sel]
    if (sum(u) == 0) {
        errprintf("the focal unit has no complete outcome path over %g-%g\n", p0, p1)
        exit(2000)
    }
    idxu = selectindex(u :== 1)
    f = M[idxu[1], .]
    sel = selectindex(u :== 0)
    A = M[sel, 1..(p1 - p0 + 1)]'           // T_pre x donors
    b = f[1..(p1 - p0 + 1)]'
    nd = cols(A)
    // sum-to-one through an augmented row with a large weight
    scale = max(abs(b)); if (scale == 0 | scale == .) scale = 1
    big = 1000 * scale
    w = _pp_nnls(A \ J(1, nd, big), b \ big, tol, maxit)
    if (sum(w) > 0) w = w / sum(w)
    // write back
    for (j = 1; j <= nd; j++) {
        rows_ = selectindex(ids :== uid[sel[j]])
        st_store(rows_, gen + "_w", J(rows(rows_), 1, w[j]))
        st_store(rows_, gen + "_peer", J(rows(rows_), 1, w[j] > 1e-8))
        st_store(rows_, gen + "_dist", J(rows(rows_), 1, sqrt(mean((A[., j] - b) :^ 2))))
    }
    // rank by weight among positive donors
    rows_ = order(-w, 1)
    k = 0
    for (j = 1; j <= nd; j++) {
        v = rows_[j]
        if (w[v] > 1e-8) {
            k++
            st_store(selectindex(ids :== uid[sel[v]]), gen + "_rank", J(rows(selectindex(ids :== uid[sel[v]])), 1, k))
        }
    }
    // path: time, focal, synthetic, gap (missing periods stay missing)
    path = J(T, 4, .)
    for (tt = 1; tt <= T; tt++) {
        path[tt, 1] = p0 + tt - 1
        path[tt, 2] = f[tt]
        if (!anyof(M[sel, tt], .)) path[tt, 3] = (M[sel, tt]' * w)
        path[tt, 4] = path[tt, 2] - path[tt, 3]
    }
    st_matrix(pathname, path)
    st_matrixcolstripe(pathname, (J(4, 1, ""), ("time" \ "focal" \ "synthetic" \ "gap")))
    st_numscalar(rmspename, sqrt(mean(path[1..(p1 - p0 + 1), 4] :^ 2)))
}

void _pp_postgap(string scalar P, real scalar p1, string scalar gname, string scalar rname)
{
    real matrix M
    real colvector g
    M = st_matrix(P)
    g = select(M[., 4], (M[., 1] :> p1) :& (M[., 4] :< .))
    if (rows(g) == 0) {
        st_numscalar(gname, .)
        st_numscalar(rname, .)
        return
    }
    st_numscalar(gname, mean(g))
    st_numscalar(rname, sqrt(mean(g :^ 2)))
}

void _pp_placebo_stats(string scalar P, real scalar g, string scalar out)
{
    real matrix M
    real scalar share, pct
    M = st_matrix(P)
    share = mean(abs(M[., 1]) :>= abs(g))
    pct = mean(M[., 1] :<= g)
    st_matrix(out, (share, pct))
}
end
