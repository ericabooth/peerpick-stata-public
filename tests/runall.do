* runall.do -- run the peerpick test battery from the tests/ folder
*   cd tests
*   do runall.do
* The data builder needs the raw downloads two folders up (data/raw); when
* they are absent the shipped data files in ../data are used as they are.
version 16
clear all
capture confirm file "../../data/raw/saipe_tx_county_2005_2023.json"
if !_rc do build_testdata.do
else di as txt "raw downloads not present; testing against the shipped data files"
do test01_methods.do
do test02_panel_subcommands.do
di as res "peerpick: every test passed"
