{smcl}
{* *! version 0.1.0  20oct2026  Eric Booth}{...}
{vieweralsosee "[R] regress" "help regress"}{...}
{vieweralsosee "[R] logit" "help logit"}{...}
{vieweralsosee "[MV] cluster kmeans" "help cluster kmeans"}{...}
{vieweralsosee "[D] xtile" "help xtile"}{...}
{viewerjumpto "Quick start" "peerpick##quickstart"}{...}
{viewerjumpto "Installation" "peerpick##install"}{...}
{viewerjumpto "Syntax" "peerpick##syntax"}{...}
{viewerjumpto "Description" "peerpick##description"}{...}
{viewerjumpto "Three choices" "peerpick##choices"}{...}
{viewerjumpto "Methods" "peerpick##methods"}{...}
{viewerjumpto "Options" "peerpick##options"}{...}
{viewerjumpto "What peerpick leaves behind" "peerpick##output"}{...}
{viewerjumpto "Checking the choice" "peerpick##checks"}{...}
{viewerjumpto "Examples" "peerpick##examples"}{...}
{viewerjumpto "The simulator" "peerpick##simulator"}{...}
{viewerjumpto "Limitations" "peerpick##limits"}{...}
{viewerjumpto "Stored results" "peerpick##results"}{...}
{viewerjumpto "References" "peerpick##refs"}{...}
{viewerjumpto "Author" "peerpick##author"}{...}

{title:Title}

{phang}
{bf:peerpick} {hline 2} Choose a comparison group for one unit, and check how much the choice matters


{marker quickstart}{...}
{title:Quick start}

{pstd}
Ten Texas counties most like Webb County on poverty, population, and share
Hispanic, drawn from counties of the same metro status, with the uninsured rate
compared:{p_end}

{phang2}{cmd:. use tx_counties, clear}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp, id(fips5) focal(48479) strata(metro) k(10) outcome(unins)}{p_end}

{pstd}
The same call, then the three checks: does the gap survive other reasonable
specifications, is it unusual next to every other county's gap, and does it
depend on any one comparison county or any one factor?{p_end}

{phang2}{cmd:. peerpick spec, k(5 10 15) distance(all) dropone}{p_end}
{phang2}{cmd:. peerpick placebo}{p_end}
{phang2}{cmd:. peerpick stability}{p_end}

{pstd}
The comparison units are flagged in {cmd:pp_peer} with weights in {cmd:pp_w},
and listed in {cmd:r(peers)}.{p_end}


{marker install}{...}
{title:Installation}

{pstd}
From GitHub:{p_end}

{phang2}{cmd:. net install peerpick, from("https://raw.githubusercontent.com/ericabooth/peerpick-stata-public/main/") replace}{p_end}

{pstd}
The example datasets and the test battery are ancillary files:{p_end}

{phang2}{cmd:. net get peerpick, from("https://raw.githubusercontent.com/ericabooth/peerpick-stata-public/main/")}{p_end}

{pstd}
{cmd:peerpick} is base Stata and Mata, with no dependencies. Stata 16 or later.{p_end}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:peerpick} [{varlist}] {ifin}{cmd:,} {opt id(varname)} {opt foc:al(value)}
[{it:options}]

{p 8 16 2}
{cmd:peerpick spec} [{cmd:,} {opt k(numlist)} {opt dist:ance(all)} {opt drop:one} {opt nostr:ata} {opt graph} {opt sav:ing(filename)} {opt nodisp:lay}]

{p 8 16 2}
{cmd:peerpick placebo} [{cmd:,} {opt graph} {opt sav:ing(filename)} {opt nodisp:lay}]

{p 8 16 2}
{cmd:peerpick stability} [{cmd:,} {opt nodisp:lay}]

{pstd}
{it:varlist} holds the {bf:factors}: the numeric variables on which comparison
units should resemble the focal unit. Some methods need none (a typology, a
hand-picked list, a trajectory, a synthetic control fitted on the outcome
alone). The dataset has one row per unit, or one row per unit and period when
{opt time()} is given.{p_end}

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab :Required}
{synopt :{opt id(varname)}}unit identifier, string or numeric{p_end}
{synopt :{opt foc:al(value)}}the focal unit: an {it:id} value, or a value of {opt name()}{p_end}

{syntab :Method}
{synopt :{opt m:ethod(name)}}{cmd:knn} (default), {cmd:cem}, {cmd:typology}, {cmd:pscore}, {cmd:predicted}, {cmd:cluster}, {cmd:entropy}, {cmd:list}, {cmd:trajectory}, {cmd:synth}; see {help peerpick##methods:Methods}{p_end}
{synopt :{opt k(#)}}number of comparison units; default {cmd:k(10)}{p_end}
{synopt :{opt dist:ance(name)}}{cmd:mahalanobis} (default) or {cmd:euclidean} on standardized factors{p_end}
{synopt :{opt w:eights(numlist)}}one weight per factor for the Euclidean distance{p_end}
{synopt :{opt str:ata(varlist)}}candidates must match the focal unit exactly on these{p_end}
{synopt :{opt cal:iper(#)}}drop candidates farther than this (distance units){p_end}
{synopt :{opt bin:s(#)}}quantile bins per factor for {cmd:cem}; default {cmd:bins(4)}{p_end}
{synopt :{opt gr:oup(varname)}}0/1 variable for {cmd:pscore}; the focal unit is in group 1{p_end}
{synopt :{opt ncl:usters(#)}}number of k-means clusters for {cmd:cluster}; default {cmd:nclusters(5)}{p_end}
{synopt :{opt seed(#)}}seed for the k-means start; default {cmd:seed(20361)}{p_end}
{synopt :{opt peers(list)}}the comparison units for {cmd:list}{p_end}

{syntab :Panel methods}
{synopt :{opt ti:me(varname)}}period variable; marks the data as a panel{p_end}
{synopt :{opt pre(# #)}}first and last period of the matching window{p_end}
{synopt :{opt post(# #)}}first and last period to follow after the window ({cmd:synth}); default is the rest of the panel{p_end}
{synopt :{opt grow:th}}match on change since the first window period rather than levels ({cmd:trajectory}){p_end}

{syntab :Outcome and reporting}
{synopt :{opt out:come(varname)}}the measure being compared; gives the gap, its interval, and the graph{p_end}
{synopt :{opt na:me(varname)}}a string label for units, used to find the focal unit and in listings{p_end}
{synopt :{opt lev:el(#)}}confidence level for the gap interval; default is {cmd:c(level)}{p_end}
{synopt :{opt gen:erate(stub)}}stub for the four new variables; default {cmd:generate(pp)}{p_end}
{synopt :{opt replace}}overwrite the generated variables{p_end}
{synopt :{opt nodisp:lay}}compute quietly{p_end}
{synopt :{opt graph}}dot plot of the focal unit and its comparison group on the outcome{p_end}
{synopt :{opt sav:ing(filename)}}save the graph{p_end}
{synopt :{opt tol:erance(#)}} and {opt iter:ate(#)}: convergence settings for {cmd:entropy} and {cmd:synth}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
Saying how a county, a city, a school, a hospital, a firm, a region, or a
country is doing usually means comparing it with a group. {cmd:peerpick} builds
that group from a dataset of candidate units of any kind, reports how well the
group resembles the focal unit on the factors you chose, reports the gap on an
outcome, and then lets you test whether the gap depends on the choices you made
along the way.{p_end}

{pstd}
Every method takes the same inputs (an id, a focal unit, factors, an optional
stratum and outcome) and leaves the same things behind (a flag, a weight, a
distance, a rank, a balance table, and a list of ids in {cmd:r(peers)}), so you
can switch the method and keep the rest of your do-file.{p_end}


{marker choices}{...}
{title:Three choices}

{pstd}
Three decisions separate "compare this unit" from a number in a report, and
{cmd:peerpick} keeps them apart so each can be stated and defended.{p_end}

{phang}{bf:The pool}: which units are candidates at all. Use {ifin} to restrict
the dataset and {opt strata()} to require an exact match on a few variables
(metro status, a sector, a size class, an ownership type). A stratum is a
strong statement: no unit outside it can be a peer, however similar.{p_end}

{phang}{bf:The factors}: the variables on which "similar" is measured. These
are the {it:varlist}. They should describe conditions the unit cannot easily
change and that plausibly drive the outcome, and they should not include the
outcome itself unless the method calls for it ({cmd:predicted},
{cmd:trajectory}, {cmd:synth}).{p_end}

{phang}{bf:The method}: how similarity on the factors is turned into a group.
That is {opt method()}, below.{p_end}


{marker methods}{...}
{title:Methods}

{pstd}
{bf:knn} (the default). The {it:k} candidates closest to the focal unit.
With {cmd:distance(mahalanobis)} the distance uses the pool's covariance, so
correlated factors are not double counted and no factor dominates by having a
larger scale. With {cmd:distance(euclidean)} each factor is standardized by the
pool's standard deviation and {opt weights()} can emphasize some factors.
{opt caliper()} drops candidates beyond a maximum distance, so fewer than {it:k}
may be returned.{p_end}

{pstd}
{bf:cem}. Coarsened cells: each factor is cut into {opt bins()} quantile bins
over the pool, and only candidates in the focal unit's bin on every factor are
eligible; within the cell the {it:k} nearest are kept. With {opt strata()} and
no factors it is the stratum itself. A small cell is a finding: the focal unit
has few close matches on those factors at that resolution.{p_end}

{pstd}
{bf:typology}. The comparison group is the cell of {opt strata()}: every unit
with the same type. Give factors as well and {it:k} nearest within the cell are
kept. This is the convention of dashboards and league tables (all rural
counties, all large urban districts, all teaching hospitals).{p_end}

{pstd}
{bf:pscore}. A logit of {opt group()} on the factors gives each unit an index
of how much it looks like the focal unit's group; the {it:k} units in group 0
nearest the focal unit on that index are the comparison group. Use it when the
focal unit belongs to a category (border counties, charter districts) and the
question is "what do units that look like they could be in this category, but
are not, do?". The category can be anything recorded as 0/1: border counties,
charter schools, firms that export, cities with a transit system.{p_end}

{pstd}
{bf:predicted}. Regress {opt outcome()} on the factors over the pool; the
comparison units are the {it:k} whose fitted values are nearest the focal
unit's fitted value. Units with the same expected outcome, whatever mix of
factors produces it. The residuals (the focal unit's and the peers' mean) are
returned, which is the "residual band" reading: is the focal unit above or
below what its conditions predict, and by more than units in the same band.{p_end}

{pstd}
{bf:cluster}. k-means on the standardized factors with {opt nclusters()}
groups; every other member of the focal unit's cluster is a peer. Group sizes
are uneven by construction, and the result depends on the seed, so {opt seed()}
is fixed by default and reported.{p_end}

{pstd}
{bf:entropy}. Entropy balancing (Hainmueller 2012): nonnegative weights over
every candidate, as close to uniform as possible, such that the weighted mean of
each factor equals the focal unit's value. Every candidate gets a weight; the
effective number of comparison units, {cmd:r(ess)}, says how concentrated they
are. If the focal unit lies outside the convex hull of the pool on the factors
(an extreme on some factor, or an unusual combination) exact balance is
impossible: {cmd:r(converged)} is 0 and {cmd:r(maximb)} reports the remaining
imbalance in standard deviations.{p_end}

{pstd}
{bf:list}. A hand-picked group given in {opt peers()}, so that an existing
convention (the eleven peer states, the comparison districts in a contract) gets
the same balance table, gap, and checks as the model-based groups.{p_end}

{pstd}
{bf:trajectory} (panel). Distance on the path of {opt outcome()} over the
{opt pre()} window: each period is standardized across units and the Euclidean
distance between paths is taken. {opt growth} matches on change since the first
window period, so units that started at different levels but moved together
are peers. Factors, if given, are reported in the balance table at the last
window period but do not enter the distance.{p_end}

{pstd}
{bf:synth} (panel). A synthetic control (Abadie, Diamond, and Hainmueller
2010): nonnegative donor weights summing to one, fitted by least squares to the
focal unit's outcome path over {opt pre()}. The weights are solved by the
Lawson-Hanson active-set algorithm with the sum-to-one constraint, so most
donors get exactly zero. {cmd:r(path)} holds the focal and synthetic paths and
the gap in every period, {cmd:r(rmspe_pre)} the fit over the window,
{cmd:r(gap_post)} the mean gap after it. No covariates enter the fit; collapse
them into the outcome path, or use them in a first-stage pool restriction with
{opt strata()} or {ifin}.{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} identifies the unit. It must be unique across rows, or across
rows within {opt time()} in a panel.

{phang}
{opt focal(value)} names the focal unit: an {it:id} value (string or numeric), or,
when {opt name()} is given, a value of the name variable. A name that matches
exactly one unit as a substring also works, so {cmd:focal(Webb)} finds
"Webb County".

{dlgtab:Method}

{phang}
{opt method(name)} chooses the method; see above. The default is {cmd:knn}.

{phang}
{opt k(#)} is the number of comparison units for {cmd:knn}, {cmd:cem},
{cmd:pscore}, {cmd:predicted}, {cmd:trajectory}, and for {cmd:typology} with
factors. Default 10.

{phang}
{opt distance(name)} is {cmd:mahalanobis} (default) or {cmd:euclidean}. The
Mahalanobis distance needs more candidates than factors; with fewer it falls
back to the standardized Euclidean distance.

{phang}
{opt weights(numlist)} gives one positive weight per factor for the Euclidean
distance. Ignored by the Mahalanobis distance.

{phang}
{opt strata(varlist)} restricts candidates to units with the focal unit's exact
values on these variables. String and numeric variables are allowed.

{phang}
{opt caliper(#)} is a maximum distance; candidates beyond it are dropped even if
fewer than {it:k} remain. In Mahalanobis units a caliper of 2 or 3 is loose; in
standardized Euclidean units it scales with the number of factors.

{phang}
{opt bins(#)} sets the quantile bins per factor for {cmd:cem}. Default 4.

{phang}
{opt group(varname)} is the 0/1 variable for {cmd:pscore}. The focal unit must
have the value 1 and the comparison units are drawn from the 0s.

{phang}
{opt nclusters(#)} and {opt seed(#)} control {cmd:cluster}: the number of k-means
groups (default 5) and the random start (default 20361).

{phang}
{opt peers(list)} gives the comparison units for {cmd:list}, as {it:id} values
separated by spaces. Values not in the pool are reported and ignored.

{dlgtab:Panel methods}

{phang}
{opt time(varname)} is the period variable. With it, {it:id} and {it:time} must
jointly identify rows, and the methods {cmd:trajectory} and {cmd:synth} become
available. The other methods still work in a panel but then use every row, which
is rarely what you want; keep one row per unit for them.

{phang}
{opt pre(# #)} gives the first and last period of the matching window. The focal
unit must have a complete outcome path over it; candidates with gaps are dropped.

{phang}
{opt post(# #)} gives the periods to follow after the window for {cmd:synth}.
The default is every period after the window.

{phang}
{opt growth} matches on change since the first window period for {cmd:trajectory}.

{dlgtab:Outcome and reporting}

{phang}
{opt outcome(varname)} is the measure compared. With it, {cmd:peerpick} reports the
focal value, the weighted peer mean, the gap, and a t-based interval using the
effective number of comparison units. In a panel the gap is reported at the
last window period, and {cmd:synth} adds the post-period mean gap. The
subcommands need it.

{phang}
{opt name(varname)} is a string label used in listings and in finding the focal
unit.

{phang}
{opt level(#)} sets the confidence level for the interval.

{phang}
{opt generate(stub)} names the four variables left behind; default {cmd:pp}.
{opt replace} overwrites them.

{phang}
{opt nodisplay} suppresses the output. {opt graph} draws a dot plot of the
focal unit and its comparison units on the outcome; {opt saving()} saves it.

{phang}
{opt tolerance(#)} and {opt iterate(#)} are the convergence tolerance (default
1e-8) and iteration limit (default 500) for {cmd:entropy} and {cmd:synth}.


{marker output}{...}
{title:What peerpick leaves behind}

{pstd}
Four variables, with the {opt generate()} stub (default {cmd:pp}):{p_end}

{phang2}{cmd:pp_peer} is 1 for a comparison unit, 2 for the focal unit, 0 for
every other unit in the sample, and missing outside it.{p_end}
{phang2}{cmd:pp_w} is the comparison weight, summing to one over the comparison
units (over each period, in a panel). Equal for the nearest-neighbour methods;
fitted for {cmd:entropy} and {cmd:synth}.{p_end}
{phang2}{cmd:pp_dist} is the distance from the focal unit on the method's
scale.{p_end}
{phang2}{cmd:pp_rank} is the rank by distance, or by weight for the weighted
methods.{p_end}

{pstd}
The output shows the method, the pool, the balance table, and the gap. The
{bf:balance table} gives, for each factor, the focal unit's value, the weighted
peer mean, the pool mean, and the {bf:standardized difference}: (peer mean
{c -} focal) / pool SD. A standardized difference near zero on every factor says
the group resembles the focal unit on the things you chose to match; a large
one says the pool has no close match on that factor, and the sign says which
way the group is off. {cmd:r(max_stddiff)} is the largest in absolute value.{p_end}

{pstd}
The {bf:gap} is the focal value minus the weighted peer mean. Its interval
treats the comparison units as a sample from the units that could have been
chosen, with a t critical value on the effective number of comparison units
minus one. It is a statement about the reference group's spread, not a test
of a policy effect; use {cmd:peerpick placebo} for the latter question.{p_end}


{marker checks}{...}
{title:Checking the choice}

{pstd}
The three subcommands replay the last {cmd:peerpick} call with one thing varied
at a time. They need {opt outcome()} in that call, and they leave the original
run's variables in place when they finish.{p_end}

{pstd}
{bf:peerpick spec} is a specification curve. It reruns the call for every
combination of {opt k()} values, both distances ({opt distance(all)}), each
factor dropped in turn ({opt dropone}), and with the strata removed
({opt nostrata}), and lists the gap, its interval, and the Jaccard overlap of
each group with the base group. {opt graph} sorts the gaps and draws them with
their intervals. A gap that changes sign or doubles across reasonable
specifications is not ready for a report; a stable one is. The table is in
{cmd:r(specs)}.{p_end}

{pstd}
{bf:peerpick placebo} makes every unit in the sample the focal unit in turn,
with its own comparison group built the same way, and asks where the real focal
unit's gap falls in that distribution. {cmd:r(share_ge)} is the share of
placebo gaps at least as large in absolute value; {cmd:r(pctile)} is the focal
gap's percentile. A gap that one unit in three would show is ordinary; one
that one unit in forty would show is worth a sentence. The gaps are in
{cmd:r(placebo)}.{p_end}

{pstd}
{bf:peerpick stability} runs two leave-one-out checks: it drops each
comparison unit from the pool and re-picks, reporting the range of the gap and
the mean overlap with the base group; and it drops each factor in turn,
reporting the gap and overlap for each. A factor whose removal changes the
group by half, as share Hispanic does for a border county, is the factor doing
the work, and that is worth saying in the report. The tables are in
{cmd:r(loo)} and {cmd:r(dropfactor)}.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
The datasets below ship with the package ({cmd:net get peerpick}): Texas
counties from the ACS 2019-23 five-year estimates, PLACES 2023, and the 2023
rural-urban continuum codes; a Texas county poverty panel from SAIPE
2005-2023; and a state panel of unemployment, income, and population from
FRED, 2000-2024.{p_end}

{pstd}{bf:Nearest neighbours within the same metro status, and the uninsured gap}{p_end}
{phang2}{cmd:. use tx_counties, clear}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) name(county_name) strata(metro) k(10) outcome(unins)}{p_end}
{phang2}{cmd:. list county_name pov hisp unins pp_dist pp_rank if inlist(pp_peer, 1, 2), noobs}{p_end}

{pstd}{bf:The same by name, with a graph}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(Webb) name(county_name) strata(metro) k(10) outcome(unins) graph replace}{p_end}

{pstd}{bf:Standardized Euclidean distance, poverty and share Hispanic counted double, and a caliper}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp medage, id(fips5) focal(48479) distance(euclidean) weights(2 1 2 1) caliper(2) k(10) outcome(unins) replace}{p_end}

{pstd}{bf:Coarsened cells: terciles on three factors, then the nearest within the cell}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp, id(fips5) focal(48479) method(cem) bins(3) k(10) outcome(unins) replace}{p_end}

{pstd}{bf:A typology: every county with the same rural-urban code and border status}{p_end}
{phang2}{cmd:. peerpick, id(fips5) focal(48479) method(typology) strata(rucc border) outcome(unins) replace}{p_end}

{pstd}{bf:Propensity score: non-border counties that look most like a border county}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) method(pscore) group(border) k(10) outcome(unins) replace}{p_end}

{pstd}{bf:Predicted value: counties with the same expected uninsured rate}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) method(predicted) outcome(unins) k(10) replace}{p_end}
{phang2}{cmd:. display "focal residual " r(focal_resid) ", peer mean residual " r(peer_resid)}{p_end}

{pstd}{bf:Cluster membership}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) method(cluster) nclusters(6) outcome(unins) replace}{p_end}

{pstd}{bf:Entropy balancing: weights so the peer means equal the focal values}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp medage, id(fips5) focal(48355) method(entropy) outcome(unins) replace}{p_end}
{phang2}{cmd:. display "converged " r(converged) ", effective n " r(ess)}{p_end}

{pstd}{bf:A hand-picked list, given the same checks}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp, id(fips5) focal(48479) method(list) peers(48061 48141 48215 48323) outcome(unins) replace}{p_end}

{pstd}{bf:Trajectory: counties whose poverty rate moved like Webb's over 2010-2019}{p_end}
{phang2}{cmd:. use tx_county_panel, clear}{p_end}
{phang2}{cmd:. peerpick, id(fips5) focal(48479) name(county_name) method(trajectory) time(year) outcome(pov) pre(2010 2019) k(8)}{p_end}
{phang2}{cmd:. peerpick, id(fips5) focal(48479) name(county_name) method(trajectory) time(year) outcome(pov) pre(2010 2019) k(8) growth replace}{p_end}

{pstd}{bf:Synthetic control: a synthetic Texas from other states' unemployment paths}{p_end}
{phang2}{cmd:. use us_states, clear}{p_end}
{phang2}{cmd:. peerpick, id(state) focal(TX) method(synth) time(year) outcome(ur) pre(2000 2009) post(2010 2024)}{p_end}
{phang2}{cmd:. matrix list r(path)}{p_end}
{phang2}{cmd:. list state year ur pp_w if pp_peer == 1 & year == 2009, noobs}{p_end}

{pstd}{bf:The checks}{p_end}
{phang2}{cmd:. use tx_counties, clear}{p_end}
{phang2}{cmd:. peerpick pov lpop hisp medage pct65 bach unemp, id(fips5) focal(48479) strata(metro) k(10) outcome(unins)}{p_end}
{phang2}{cmd:. peerpick spec, k(5 10 15) distance(all) dropone nostrata graph}{p_end}
{phang2}{cmd:. peerpick placebo, graph}{p_end}
{phang2}{cmd:. peerpick stability}{p_end}

{pstd}{bf:Loop over many focal units and collect the groups}{p_end}
{phang2}{cmd:. levelsof fips5 if metro == 1, local(units) clean}{p_end}
{phang2}{cmd:. foreach u of local units {c -(}}{p_end}
{phang2}{cmd:.     peerpick pov lpop hisp medage, id(fips5) focal(`u') strata(metro) k(10) outcome(unins) nodisplay replace}{p_end}
{phang2}{cmd:.     display "`u': gap " %5.2f r(gap) "  peers " r(peers)}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{pstd}{bf:Keep the group and merge it onto another file}{p_end}
{phang2}{cmd:. keep if inlist(pp_peer, 1, 2)}{p_end}
{phang2}{cmd:. keep fips5 county_name pp_peer pp_w pp_dist pp_rank}{p_end}
{phang2}{cmd:. save build/peers_webb_uninsured, replace}{p_end}


{marker simulator}{...}
{title:The simulator}

{pstd}
A companion page, {cmd:simulator/peer_simulator.html}, lets you make the same
three choices by hand and watch the result: pick a unit type, a question, and a
method, then move the settings (focal unit, factors, k, strata, caliper) and see
the comparison group, the gap, the balance, and the sensitivity change, with
notes and references that follow the settings. Counties use the real data
shipped here; the other unit types are simulated for teaching. It is one file
with no server and no internet connection needed: {cmd:net get peerpick} fetches
it, or open it online at
{browse "https://ericabooth.github.io/peerpick-stata-public/simulator/peer_simulator.html"}.{p_end}


{marker limits}{...}
{title:Limitations}

{pstd}
One focal unit per call. To build groups for many units, loop over them with
{opt nodisplay} and collect {cmd:r(peers)} or the generated variables.{p_end}

{pstd}
The methods are deliberately plain: no covariate weighting inside {cmd:synth},
no cross-validated bandwidths, no doubly robust estimators. For those, build
the pool and factors here and hand the data to a dedicated estimation command.{p_end}

{pstd}
The Mahalanobis distance uses the pool's covariance matrix. With strongly
collinear factors it is still defined (a generalized inverse is used) but the
distance then reflects the subspace the factors span. Prefer fewer, less
redundant factors.{p_end}

{pstd}
The replay subcommands rebuild the last call from its text, so they need the
original dataset in memory and the generated variables present (they are
overwritten and restored).{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:peerpick} stores the following in {cmd:r()}:{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt :{cmd:r(k)}}number of comparison units{p_end}
{synopt :{cmd:r(N_pool)}}candidates after {ifin} and {opt strata()}{p_end}
{synopt :{cmd:r(ess)}}effective number of comparison units, (sum w)^2 / sum w^2{p_end}
{synopt :{cmd:r(focal_y)}}focal value of the outcome{p_end}
{synopt :{cmd:r(peer_y)}}weighted peer mean of the outcome{p_end}
{synopt :{cmd:r(peer_sd)}}weighted peer standard deviation{p_end}
{synopt :{cmd:r(gap)}}focal minus peer mean{p_end}
{synopt :{cmd:r(se)}}, {cmd:r(lb)}, {cmd:r(ub)}, {cmd:r(level)}: standard error and interval of the gap{p_end}
{synopt :{cmd:r(max_stddiff)}}largest absolute standardized difference in the balance table{p_end}
{synopt :{cmd:r(gap_time)}}period at which the gap is reported (panel methods){p_end}
{synopt :{cmd:r(cell_n)}}candidates in the cell ({cmd:cem}, {cmd:typology}){p_end}
{synopt :{cmd:r(pscore_focal)}}fitted probability for the focal unit ({cmd:pscore}){p_end}
{synopt :{cmd:r(r2)}}, {cmd:r(focal_fitted)}, {cmd:r(focal_resid)}, {cmd:r(peer_resid)}: regression fit, focal fitted value, focal residual, peer mean residual ({cmd:predicted}){p_end}
{synopt :{cmd:r(cluster_n)}}members of the focal unit's cluster ({cmd:cluster}){p_end}
{synopt :{cmd:r(converged)}}, {cmd:r(maximb)}: convergence flag and remaining imbalance in SD units ({cmd:entropy}){p_end}
{synopt :{cmd:r(donors)}}, {cmd:r(rmspe_pre)}, {cmd:r(rmspe_post)}, {cmd:r(gap_post)}: donors with positive weight, fit over the window, fit after it, mean post-period gap ({cmd:synth}){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt :{cmd:r(peers)}}ids of the comparison units{p_end}
{synopt :{cmd:r(focal)}}id of the focal unit{p_end}
{synopt :{cmd:r(method)}}, {cmd:r(distance)}, {cmd:r(factors)}, {cmd:r(strata)}, {cmd:r(id)}, {cmd:r(outcome)}, {cmd:r(generate)}{p_end}
{synopt :{cmd:r(note)}}a one-line note on the method's result{p_end}
{synopt :{cmd:r(cmdline)}}the call{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt :{cmd:r(balance)}}factors by (focal, peers, pool, stddiff){p_end}
{synopt :{cmd:r(path)}}periods by (time, focal, synthetic, gap) ({cmd:synth}){p_end}
{p2colreset}{...}

{pstd}{cmd:peerpick spec} stores {cmd:r(specs)} (spec, k, mahalanobis, dropped,
strata, npeers, gap, lb, ub, jaccard), {cmd:r(n_spec)}, {cmd:r(gap_min)},
{cmd:r(gap_max)}, {cmd:r(gap_base)}.{p_end}

{pstd}{cmd:peerpick placebo} stores {cmd:r(placebo)} (gap, npeers, focal),
{cmd:r(n_placebo)}, {cmd:r(share_ge)}, {cmd:r(pctile)}, {cmd:r(gap_base)}.{p_end}

{pstd}{cmd:peerpick stability} stores {cmd:r(loo)} (gap, npeers, jaccard; one
row per dropped comparison unit), {cmd:r(dropfactor)} (the same, one row per
dropped factor), {cmd:r(gap_base)}.{p_end}


{marker refs}{...}
{title:References}

{phang}Abadie, A., A. Diamond, and J. Hainmueller. 2010. Synthetic control
methods for comparative case studies: Estimating the effect of California's
tobacco control program. {it:Journal of the American Statistical Association}
105: 493-505. {browse "https://doi.org/10.1198/jasa.2009.ap08746":doi:10.1198/jasa.2009.ap08746}{p_end}

{phang}Hainmueller, J. 2012. Entropy balancing for causal effects: A
multivariate reweighting method to produce balanced samples in observational
studies. {it:Political Analysis} 20: 25-46.
{browse "https://doi.org/10.1093/pan/mpr025":doi:10.1093/pan/mpr025}{p_end}

{phang}Iacus, S. M., G. King, and G. Porro. 2012. Causal inference without
balance checking: Coarsened exact matching. {it:Political Analysis} 20: 1-24.
{browse "https://doi.org/10.1093/pan/mpr013":doi:10.1093/pan/mpr013}{p_end}

{phang}Lawson, C. L., and R. J. Hanson. 1974. {it:Solving Least Squares
Problems}. Englewood Cliffs, NJ: Prentice-Hall. Reprinted 1995, Philadelphia:
SIAM. {browse "https://doi.org/10.1137/1.9781611971217":doi:10.1137/1.9781611971217}{p_end}

{phang}Rosenbaum, P. R., and D. B. Rubin. 1985. Constructing a control group
using multivariate matched sampling methods that incorporate the propensity
score. {it:The American Statistician} 39: 33-38.
{browse "https://doi.org/10.1080/00031305.1985.10479383":doi:10.1080/00031305.1985.10479383}{p_end}

{phang}Simonsohn, U., J. P. Simmons, and L. D. Nelson. 2020. Specification
curve analysis. {it:Nature Human Behaviour} 4: 1208-1214.
{browse "https://doi.org/10.1038/s41562-020-0912-z":doi:10.1038/s41562-020-0912-z}{p_end}

{phang}Stuart, E. A. 2010. Matching methods for causal inference: A review and
a look forward. {it:Statistical Science} 25: 1-21.
{browse "https://doi.org/10.1214/09-STS313":doi:10.1214/09-STS313}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Eric A. Booth{break}
Sr Researcher, Texas 2036{break}
{browse "mailto:eric.a.booth@gmail.com":eric.a.booth@gmail.com}{break}
{browse "https://github.com/ericabooth":github.com/ericabooth}{p_end}

{pstd}MIT License. Report issues at the
{browse "https://github.com/ericabooth/peerpick-stata-public":GitHub repository}.{p_end}
