//EITC GENEROSITY AND FOOD PURCHASES
//REX SITTI
//APRIL 4TH 2025

* Set root working directory
cd "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data"

* Loop through years 2004 to 2019
forvalues year = 2004/2019 {
    
    * Display progress
    di "Processing year `year'..."
    
    * Get last two digits of year (for filenames)
    local yy = substr("`year'", 3, 2)
    
    * Define file paths
    local folder = "intrvw`yy'"
    local files fmli`yy'4.csv fmli`yy'3.csv fmli`yy'2.csv fmli`yy'1x.csv

    * Create temporary master file for appending
    clear
    tempfile master_`year'
    save `master_`year'', emptyok

    * Loop over the four files for the year
    foreach file in `files' {
        * Build full path
        local fullpath = "`folder'/`file'"
        
        * Import CSV
        capture noisily import delimited "`fullpath'", clear
        if _rc != 0 {
            di as error "File not found or error reading: `fullpath'"
            continue
        }

        * Check if newid exists and is unique
        capture noisily isid newid

        * Save individual .dta file
        local dta = subinstr("`file'", ".csv", ".dta", .)
        save "`folder'/`dta'", replace

        * Append to master
        append using `master_`year''
        save `master_`year'', replace
    }

    * Final processing
    isid newid
    tostring newid, replace

    * Save final yearly dataset
    save "FMLII1234_`year'.dta", replace
}


* Set working directory
cd "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data"

* Create an empty dataset to start appending into
clear
tempfile master
save `master', emptyok

* Variables to standardize as strings if needed
local fixvars psu busc_een

* Loop through each year and append
forvalues year = 2004/2019 {

    di "Appending year `year'..."

    * Load the yearly dataset
    use FMLII1234_`year'.dta, clear

    * Convert any problematic variables to string if they exist and are not already string
    foreach var of local fixvars {
        capture confirm variable `var'
        if _rc == 0 {
            capture confirm string variable `var'
            if _rc != 0 {
                tostring `var', replace force
            }
        }
    }

    * Add year variable
    gen year = `year'

    * Append to master
    append using `master'
    save `master', replace
}

* Optional: Save the full appended dataset
compress
save "FMLII_all_years_2004_2019.dta", replace


* Merge EITC state-level data
rename state statefips
merge m:1 statefips year using ///
    "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\Stata\EITC_state.dta", ///
    keep(match) generate(eitc_shr)

drop statefips

* Merge State Controls
merge m:1 state_year using ///
    "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\Stata\State level controls.dta", ///
    keep(match) generate(state_ctrl1)

* Drop again in case Refund Binary re-added statefips
capture drop statefips

* Drop any leftover merge indicators and redundant variables
capture drop _merge
capture drop _state state_year2 state_ state_ctrl1 

* Keep only relevant variables
keep newid state year tottxpdx finlwt21 age_ref bls_urbn educ_ref ///
    fam_size fam_type earncomp fssix inc_rank marital1 perslt18 qintrvmo ///
    qintrvyr race2 ref_race region sex_ref sex2 totexppq totexpcq ///
    foodpq foodcq fdhomepq fdhomecq fdawaypq fdawaycq alcbevcq alcbevpq ///
    healthcq healthpq hlthinpq hlthincq medsrvpq medsrvcq predrgpq predrgcq ///
    talcbevc talcbevp tentrmnc tobaccpq tobacccq entertcq entertpq inclass ///
    childage tfoodtop tfoodtoc tfoodawp tfoodawc cuid fsalarym fssix eitc ///
    eitc_state eitc_state_lag eitc_state_refundable jfs_amt earncomp ///
    cooking persot64 urate povrate

	// Turn off output
set more off

// Destring variables
destring ref_race marital marital1 qintrvmo year fam_type, replace
destring earncomp, gen(earncomp1)

// --- RACE VARIABLES ---
gen white1         = (ref_race == 1)
gen black          = (ref_race == 2)
gen native_america = (ref_race == 3)
gen asian          = (ref_race == 4)
gen multirace      = (ref_race == 6)

// --- INCOME CATEGORIES ---
gen less_20k     = (fsalarym < 20000)
gen btw_20k_50k  = (fsalarym > 20000 & fsalarym < 50000)
gen btw_50k_80k  = (fsalarym > 50000 & fsalarym < 80000)
gen above_80k    = (fsalarym > 80000)

// --- MARITAL STATUS CATEGORIES ---
gen married1       = (marital == 1)
gen wid_div_sep    = inlist(marital, 2, 3, 4)
gen nevr_married1  = (marital == 5)

// --- QUARTERS ---
gen quarters = .
replace quarters = 1 if qintrvmo < 4
replace quarters = 2 if inrange(qintrvmo, 4, 6)
replace quarters = 3 if inrange(qintrvmo, 7, 9)
replace quarters = 4 if qintrvmo > 9

// --- EITC MONTHS (April to August) ---
gen eitcmths = inrange(qintrvmo, 4, 8)

// --- FOOD RATIOS ---
gen ratio_fdhmpq = fdhomepq / foodpq
drop if missing(ratio_fdhmpq)

gen ratio_fdhmcq = fdhomecq / foodcq
replace ratio_fdhmcq = 0 if missing(ratio_fdhmcq)

gen ratio_alc = alcbevcq / (foodcq + alcbevcq + tobacccq)
gen ratio_tob = tobacccq / (foodcq + alcbevcq + tobacccq)
replace ratio_alc = 0 if missing(ratio_alc)
replace ratio_tob = 0 if missing(ratio_tob)

gen ratio_fdawypq = fdawaypq / foodpq
gen ratio_fdawycq = fdawaycq / foodcq
drop if missing(ratio_fdawycq)

// --- EAT IN / EAT OUT ---
gen eatout = (fdawaycq > 0)
gen eatin  = (fdhomecq > 0)

// --- AGE, LOGS, AND OTHER CONTROLS ---
gen agesq = age_ref^2
gen ln_inc = ln(fsalarym + 1)
gen ln_alc = ln(alcbevcq + 1)
gen ln_tob = ln(tobacccq + 1)
gen yrsqrd = year^2
gen ln_fdawy = ln(fdawaycq + 1)
gen ln_fdhm  = ln(fdhomecq + 1)
gen fdhm_binary = (fdhomecq > 0)

// --- RESTRICT SAMPLE TO WORKING AGE RANGE ---
drop if age_ref > 65

// --- CHILD TAX CREDIT STATES ---
 gen ctc = inlist(state, "8", "19", "22", "31", "35", "36", "39", "50")
 
// --- CHILD COUNT CATEGORIES ---
gen nochild        = (perslt18 == 0)
gen onechild       = (perslt18 == 1)
gen twochild       = (perslt18 == 2)
gen atleast3child  = (perslt18 > 2)

gen atleast4 = (fam_size >= 4)
gen atleast3 = (fam_size >= 3)

// --- BINARY MARRIED VARIABLE ---
gen married = (marital1 == 1)
recode married (.=0)

// --- TOTAL TAX PAID ---
recode tottxpdx (.=0)

// --- FIX YEAR NAME ---
drop year
rename qintrvyr year

// --- VARIABLE LABELS ---
label variable age_ref "Age of the head of the household"
label variable bls_urbn "Dummy for urban and rural"
//

// --- LABEL DEFINITIONS ---
label define marital1 1 "married" 2 "widowed" 3 "divorced" 4 "separated" 5 "never married", replace
label values marital1 marital1

label define fam_type ///
    1 "Married couple" ///
    2 "Married couple, oldest child <6" ///
    3 "Husband, wife and oldest child>17" ///
    4 "Married couple and oldest child >17" ///
    5 "All other" ///
    6 "One parent, male, at least one child <18" ///
    7 "One parent, female, at least one child <18" ///
    8 "Single" ///
    9 "Other families"
label values fam_type fam_type

label define earncomp 1 "Only ref person" 2 "..."
	
/*
//Subsection 1.1: Merging FMLI Datasets from the Consumer expenditure survey (U.S Bureau of Labor Statistics)

	//FMLI1234_2004 - Improting annual files from the FMLI dataset
	//year 2004
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli044.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli044.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli043.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli043.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli042.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli042.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli041x.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli041x.dta", replace

	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli044.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli043.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw04\fmli042.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2004.dta", replace

	//FMLI1234_2005 - year 2005
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\fmli054.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\fmli054.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\FMLI053.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\FMLI053.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\fmli052.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\FMLI052.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\fmli051x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\fmli054.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\FMLI053.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw05\FMLI052.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2005.dta", replace

	//FMLI1234_2006 - year 2006
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\fmli064.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\fmli064.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\fmli063.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\FMLI063.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\fmli062.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\FMLI062.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\fmli061x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\fmli064.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\FMLI063.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw06\FMLI062.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2006.dta", replace

	//FMLI1234_2007 -year 2007
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\fmli074.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\fmli074.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\fmli073.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\fmli073.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\fmli072.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\FMLI072.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\fmli071x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\fmli074.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\FMLI073.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw07\FMLI072.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2007.dta", replace

	//FMLI1234_2008 - year 2008
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\fmli082.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\fmli082.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\fmli083.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\FMLI083.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\fmli084.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\fmli084.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\fmli081x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\fmli084.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\FMLI083.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw08\FMLI082.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2008.dta", replace

	//FMLI1234_2009 - year 2009
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\fmli092.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\FMLI092.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\fmli094.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\fmli094.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\fmli093.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\FMLI093.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\fmli091x.csv"
	isid newid

	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\fmli094.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\FMLI093.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw09\FMLI092.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2009.dta", replace

	//FMLI1234_2010 - year 2010
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\fmli102.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\FMLI102.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\fmli103.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\FMLI103.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\fmli104.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\fmli104.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\fmli101x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\fmli104.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\FMLI103.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw10\FMLI102.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2010.dta", replace

	//FMLI1234_2011 - year 2011
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\fmli112.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\FMLI112.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\fmli113.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\FMLI113.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\fmli114.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\fmli114.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\fmli111x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\fmli114.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\FMLI113.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw11\FMLI112.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2011.dta", replace

	//FMLI1234_2012 - year 2012
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\fmli122.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\FMLI122.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\fmli123.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\FMLI123.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\fmli124.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\fmli124.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\fmli121x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\fmli124.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\FMLI123.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw12\FMLI122.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2012.dta", replace

	//FMLI1234_2013 - year 2013
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli133.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli133.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli132.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli132.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli134.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli134.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli131x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli134.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli132.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw13\fmli133.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2013.dta", replace

	//FMLI1234_2014 - year 2014
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw14\fmli143.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw14\fmli143.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw14\fmli142.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw14\fmli142.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw14\fmli144.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw14\fmli144.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\fmli141x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw14\fmli144.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw14\fmli142.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw14\fmli143.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2014.dta", replace

	//FMLI1234_2015 - year 2015
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw15\fmli153.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw15\fmli153.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw15\fmli152.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw15\fmli152.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw15\fmli154.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw15\fmli154.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\fmli151x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw15\fmli154.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw15\fmli152.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw15\fmli153.dta"
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2015.dta", replace

	//FMLI1234_2016 - year 2016
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw16\fmli163.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw16\fmli163.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw16\fmli162.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw16\fmli162.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw16\fmli164.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw16\fmli164.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\fmli161x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw16\fmli164.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw16\fmli163.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw16\fmli162.dta"
	isid newid
	tostring newid, replace
	drop busc_een
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2016.dta", replace

	//FMLI1234_2017 - year 2017
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli173.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli173.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli172.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli172.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli174.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli174.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli171x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli174.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli173.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw17\fmli172.dta"
	isid newid
	tostring newid, replace
	drop busc_een
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2017.dta", replace

	//FMLI1234_2018 - year 2018
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw18\fmli183.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw18\fmli183.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw18\fmli182.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw18\fmli182.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw18\fmli184.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw18\fmli184.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\fmli181x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw18\fmli184.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw18\fmli182.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw18\fmli183.dta" 
	isid newid
	tostring newid, replace
	drop busc_een
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2018.dta", replace

	//FMLI1234_2019 - year 2019
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli193.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli193.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli192.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli192.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli194.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli194.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli191x.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli194.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli192.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli193.dta" 
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2019.dta", replace
	drop busc_een

	//FMLI1234_2019 - year 2020
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw20\fmli203.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw20\fmli203.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw20\fmli202.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw20\fmli202.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw20\fmli204.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw20\fmli204.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw19\fmli201.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw20\fmli204.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw20\fmli202.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw20\fmli203.dta" 
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2020.dta", replace
	
	//FMLI1234_2019 - year 2021
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli213.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli213.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli212.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli212.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli214.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli214.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli221.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli214.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli212.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw21\fmli213.dta" 
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2021.dta", replace
	
	//FMLI1234_2019 - year 2022
	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli223.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli223.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli222.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli222.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli224.csv"
	isid newid
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli224.dta", replace

	clear all
	import delimited "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli231.csv"
	isid newid
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli224.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli222.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\intrvw22\fmli223.dta" 
	isid newid
	tostring newid, replace
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2022.dta", replace
		
	///FMLI1234_13141516171819
	append using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2019.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2021.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2018.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2004.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2017.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2016.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2015.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2014.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2013.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2012.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2011.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2010.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2009.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2008.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2007.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2006.dta" "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLII1234_2005.dta", force
	save "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\CE PUMD Data\FMLI1234_13141516171819.dta", replace

	merge m:1 statefips year using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\Stata\EITC_state.dta", keep(match) generate(eitc_shr)
	drop statefips
	merge m:1 state_year using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\Stata\State level controls.dta", keep(match) generate(state_ctrl1)
	
	merge m:1 state_year using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\stata\Refund Binary.dta", keep(match) nogenerate
	drop statefips
	merge m:1 state_year using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\Stata\Additional Vars.dta", nogen
	
	drop _merge
	merge m:1 state_year using "C:\Users\rsitti\OneDrive - Old Dominion University\EITC Project\Stata\MOE Basic Assistance.dta"
	
	drop _state state_year2 state_ state_ctrl1 state_year
	//Keeping only variables needed
keep newid state year Refund tottxpdx finlwt21 age_ref bls_urbn educ_ref fam_size fam_type earncomp fssix inc_rank marital1 perslt18 qintrvmo qintrvyr race2 ref_race region sex_ref sex2 totexppq totexpcq foodpq foodcq fdhomepq fdhomecq fdawaypq fdawaycq alcbevcq alcbevpq healthcq healthpq hlthinpq hlthincq medsrvpq medsrvcq predrgpq predrgcq talcbevc talcbevp tentrmnc tobaccpq tobacccq entertcq entertpq inclass childage tfoodtop tfoodtoc tfoodawp tfoodawc cuid fsalarym fssix eitc eitc_state eitc_state_lag eitc_state_refundable jfs_amt earncomp cooking  persot64  urate povrate  MOE
*/
/*set more off
destring ref_race, replace
gen white1 = 0
replace white1=1 if ref_race==1
gen black = 0
replace black = 1 if ref_race==2
gen native_america = 0
replace native_america = 1 if ref_race==3
gen asian = 0
replace asian = 1 if ref_race==4
gen multirace = 0
replace multirace = 1 if ref_race==6
gen less_20k = 0
replace less_20k = 1 if fsalarym < 20000
gen btw_20k_50k = 0
replace btw_20k_50k = 1 if fsalarym > 20000 & fsalarym < 50000
gen btw_50k_80k = 0
replace btw_50k_80k = 1 if fsalarym > 50000 & fsalarym < 80000
gen above_80k = 0
replace above_80k = 1 if fsalarym > 80000 
gen married1 = 0
replace married1 = 1 if marital==1
gen wid_div_sep = 0
destring marital, replace
replace wid_div_sep = 1 if marital ==2
replace wid_div_sep = 1 if marital ==3
replace wid_div_sep = 1 if marital ==4
gen nevr_married1 = 0
replace nevr_married= 1 if marital == 5

//generating quarterly variable
destring qintrvmo, replace
gen quarters = . 
recode quarters (.= 1) if qintrvmo <4
recode quarters (.=2) if qintrvmo > 3 & qintrvmo <7
recode quarters (.=3) if qintrvmo >6 & qintrvmo < 10
recode quarters (.=4) if qintrvmo >9 

//generating eitc months
gen eitcmths = 0
recode eitcmths (0=1) if qintrvmo > 3 & qintrvmo <9 

//generating ratio of food at home previous quarter
gen ratio_fdhmpq = fdhomepq/foodpq
drop if ratio_fdhmpq ==.

//generating ratios for tobacco and alcoholic
gen ratio_alc = alcbevcq/(foodcq+alcbevcq+tobacccq)
gen ratio_tob = tobacccq/(foodcq+alcbevcq+tobacccq)
replace ratio_alc = 0 if ratio_alc==.
replace ratio_tob = 0 if ratio_tob ==.

//replace ratio_fdhmpq = 0 if ratio_fdhmpq ==.

//generating ratio of food at home this quarter
gen ratio_fdhmcq  = fdhomecq/foodpq
replace ratio_fdhmcq = 0 if ratio_fdhmcq ==.

//generating binary eating out
gen eatout = fdawaycq 
replace eatout = 0 if fdawaycq == 0
replace eatout = 1 if fdawaycq > 0
gen eatin = fdhomecq 
replace eatin = 0 if fdhomecq == 0
replace eatin = 1 if fdhomecq > 0


//generating ratio of food at home this and previous quarter
gen ratio_fdawypq = fdawaypq/foodpq
gen ratio_fdawycq = fdawaycq/foodcq
drop if ratio_fdawycq ==.

//replace ratio_fdawypq = 0 if ratio_fdhmcq ==.

//replace ratio_fdawycq = 0 if ratio_fdhmcq ==.


//generating age squared, log of wage and seitc
gen agesq = age_ref^2
gen ln_inc = ln(fsalarym+1)
gen seitc = 0
replace seitc = 1 if seitc_cy > 0

//generating log of alcohol and tobacco
gen ln_alc = ln(alcbevcq+1)
gen ln_tob = ln(tobacccq+1)
gen yrsqrd = year^2

//generating log of dependent variables
gen ln_fdawy = ln(fdawaycq+1)
gen ln_fdhm = ln(fdhomecq+1)

gen fdhm_binary =0
recode fdhm_binary (0=1) if fdhomecq > 0

//restricting sample to working age range (16 to 65)
drop if age_ref >65

//child tax credit
gen ctc = 0
replace ctc = 1 if statefips ==8
replace ctc = 1 if statefips ==19
replace ctc = 1 if statefips ==22
replace ctc = 1 if statefips ==31
replace ctc = 1 if statefips ==35
replace ctc = 1 if statefips ==39
replace ctc = 1 if statefips ==50
replace ctc = 1 if statefips ==36

//to generate categories of number of children by age 0, 1 and 3+
gen nochild = 1 if perslt18 == 0
recode nochild (.=0)
gen onechild = 1 if perslt18 ==1
recode onechild (.=0)
gen twochild = 1 if [perslt18 ==2]
recode twochild (.=0)
gen atleast3child = 1 if perslt18 >2
recode atleast3child (.=0)
gen atleast4 = 1
recode atleast4 (1=0) if fam_size < 4
gen atleast3 = 1
recode atleast3 (1=0) if fam_size < 3

//generating a dichotomous marrital variables versus non-married categories
destring marital1, replace
gen married = 1 if marital1 == 1
recode married (.=0)
destring married, replace

//total tax paid
recode tottxpdx (.=0)

//renaming year variable
drop year
rename qintrvyr year

lab var age_ref "Age of the head of the household" 
lab var bls_urbn "Dummy for urban and rural" 
lab var educ_ref "Education level of the head of the household" 
lab var educa2 "Education level of spouse" 
lab var fam_size "Family size" 
lab var fssix "Supplemental security income" 
lab var inc_rank "Income ranking to total population" 
lab var marital1 "Marital status" 
lab var perslt18 "Number of children under 18" 
lab var race2 "Race of spouse"
lab var ref_race "Race of respondent"
lab var region "Region" 
lab var sex_ref "Gender of respondent" 
lab var sex2 "Gender of spouse" 
lab var totexpcq "Total expenditure current quarter" 
lab var totexppq "Total expenditure previous quarter" 
lab var foodpq "Total food expenditure previous quarter" 
lab var foodcq "Total food expenditure current quarter"
lab var ref_race "Race of respondent"
lab var fdhomecq "Food at home expenditure current quarter"
lab var foodcq "Total food this quarter"
lab var fdhomepq "Food at home expenditure previous quarter"
lab var foodpq "Total food previous quarter"
lab var fdawaycq "Food away from home expenditure current quarter"
lab var fdawaypq "Food away from home expenditure previous quarter"
lab var healthpq "Health care expenses previous quarter"
lab var healthcq "health care expenses current quarter"
lab var ratio_fdhmpq "Ratio of food at home over total food previous quarter"
lab var ratio_fdhmcq "Ratio of food at home over total food current quarter"	
lab var ratio_fdawypq "Ratio of food away from home over total food previous quarter"
lab var ratio_fdawycq "Ratio of food away from home over total food current quarter"		
lab var jfs_amt "Amount of SNAP received"
lab var eitc "Earned Income Tax Credit"
lab var age2 "Age of spouse"
lab var fam_type "Family type"
lab var earncomp "Composition of earners in household"
lab var finlwt21 "Final weight of the full sample"
lab var qintrvmo "Month of the interview"
lab var year "Year of the interview"
lab var alcbevcq "Expenditure on alcohol this quarter"
lab var alcbevpq "Expenditure on alcohol previous quarter"
lab var hlthincq "Expenditure on health insurance this quarter"
lab var hlthinpq "Expenditure on health insurance previous quarter"
lab var medsrvcq "Expenditure on medical services this quarter"
lab var medsrvpq "Expenditure on medical services previous quarter"
lab var predrgcq "Expenditure on prescription drugs this quarter"
lab var predrgpq "Expenditure on prescription drugs previous quarter"
lab var talcbevc "Expenditure on alcoholic drinks trips this quarter"
lab var talcbevp "Expenditure on alcoholic drinks trips previous quarter"
lab var tobacccq "Expenditure on tobacco this quarter"
lab var tobaccpq "Expenditure on tobacco previous quarter"
lab var hh_cu_q "Number of houuseholds in unit"
lab var childage "Age of child"
lab var hhid "Household identification"
lab var state "State"
lab var tfoodtoc "Trip expenditure on food this quarter"
lab var tfoodtop "Trip expenditure on food previous quarter"
lab var tfoodawc "Trip expenditure on food away from home this quarter"
lab var tfoodawp "Trip expenditure on food away from home previous quarter"
lab var tentrmnc "Trip expenditure on entertainment this quarter"
lab var fsalarym "Income from wages and salary annualized"
lab var fssix "Supplimental security income"
lab var entertpq "Expenditure on entertainment previous quarter"
lab var entertcq "Expenditure on entertainment this quarter"
lab var agesq "Age squared"
lab var ln_inc "Log of income"
lab var psu "Primary sampling unit"
lab var onechild "One child"
lab var nochild "No child"
lab var twochild "Two children"
lab var atleast3child "Three or more children"
lab var married "Living with a spouse dummy"
lab var earncomp "Composition of earners"

//converting variables from string and defining labels
destring year, replace 
destring marital1, replace
label define marital1 1 "married" 2 "widowed" 3 "divorced" 4 "separated" 5 "never married", replace
label values marital1 marital1
destring fam_type, replace
label define fam_type 1 "Married couple" 2 "Married couple, oldest child <6" 3 "Husband, wife and oldest child>17" 4 "Married couple and oldest child >17" 5 "All other" 6 "one parent, male, atleast one child <18" 7 "One parent, female, atleast one child <18" 8 "Single" 9 "other families"
label values fam_type fam_type
destring earncomp, gen(earncomp1)
label define earncomp 1 "Only ref person" 2 "Ref person and spouse" 3 "Ref person, spouse and other" 4 "Ref person and others" 5 "Spouse only" 6 "Spouse and others" 7 "others" 8 "No earners"
label values earncomp1 earncomp
destring earncomp, replace
recode earncomp (8=0)(5=1)(4=3)(6=3)(7=2)
label define earncomp_ 0 "No earners" 1 "Only one person" 2 "Two members" 3 "Three or more" 
label values earncomp earncomp_
recode DemControl (.=0)
destring state, gen(state_s)
label values state_s state
destring ref_race, replace
label define ref_race 1 "white" 2 "Black" 3 "American Indian" 4 "Asian" 5 "Native Hawaian/ pacific" 6 "Multi-race", replace
label values ref_race ref_race
gen white =1 if ref_race==1
recode white (.=0)
destring region, replace
label define region 1 "Northeastern" 2 "Midwest" 3 "South" 4 "West", replace
label values region region
destring bls_urbn, gen(RURAL)
recode RURAL (1=0)(2=1)
label define bls_urbn 0 "Urban" 1 "Rural"
label values RURAL bls_urbn
destring eitc, replace
recode eitc (2=0)
destring ref_race, replace
label define race 1 "white" 2 "African American/ Black" 3 "Native American" 4 "Asian" 5 "Pacific Islander" 6 "Multi-race" 
label values ref_race race
destring cooking, replace
destring sex2, replace
destring state, replace
destring educ_ref, replace

//cleaning marital variable
recode marital1 (.= 1) if fam_type ==1
recode marital1 (.= 5) if fam_type ==8
recode marital1 (.= 1) if fam_type ==4
recode marital1 (.= 1) if fam_type ==3
recode marital1 (.= 5) if fam_type ==9
recode marital1 (.= 1) if fam_type ==2
recode marital1 (.= 4) if fam_type ==6
recode marital1 (.= 4) if fam_type ==7
recode marital1 (.= 5) if earncomp ==4
recode marital1 (.= 4) if earncomp ==5
recode marital1 (.= 1) if earncomp ==2
recode marital1 (.= 1) if earncomp ==3
recode marital1 (.= 1) if fam_type ==5
*/

// ------------------- LABEL STATES -------------------
* STEP 1: Extract the state FIPS code as a string
gen state = substr(state_year, 1, 2)

/* STEP 2: Check the results
list state_year state in 1/10


label define state ///
1 "Alabama" 2 "Alaska" 4 "Arizona" 6 "California" 8 "Colorado" 9 "Connecticut" ///
10 "Delaware" 11 "District of Columbia" 12 "Florida" 13 "Georgia" 15 "Hawaii" 16 "Idaho" ///
17 "Illinois" 18 "Indiana" 19 "Iowa" 20 "Kansas" 21 "Kentucky" 22 "Louisiana" 23 "Maine" ///
24 "Maryland" 25 "Massachusetts" 26 "Michigan" 27 "Minnesota" 28 "Mississippi" 29 "Missouri" ///
30 "Montana" 31 "Nebraska" 32 "Nevada" 33 "New Hampshire" 34 "New Jersey" 35 "New Mexico" ///
36 "New York" 37 "North Carolina" 38 "North Dakota" 39 "Ohio" 40 "Oklahoma" 41 "Oregon" ///
42 "Pennsylvania" 44 "Rhode Island" 45 "South Carolina" 46 "South Dakota" 47 "Tennessee" ///
48 "Texas" 49 "Utah" 50 "Vermont" 51 "Virginia" 53 "Washington" 54 "West Virginia" ///
55 "Wisconsin" 56 "Wyoming" 72 "Puerto Rico" 78 "Virgin Islands", replace

rename state statefips

preserve
clear
input str2 state str20 state1
"01" "Alabama"
"02" "Alaska"
"03" "Arizona"
"04" "Arkansas"
"05" "California"
"06" "Colorado"
"07" "Connecticut"
"08" "Delaware"
"09" "Florida"
"10" "Georgia"
"11" "Hawaii"
"12" "Idaho"
"13" "Illinois"
"14" "Indiana"
"15" "Iowa"
"16" "Kansas"
"17" "Kentucky"
"18" "Louisiana"
"19" "Maine"
"20" "Maryland"
"21" "Massachusetts"
"22" "Michigan"
"23" "Minnesota"
"24" "Mississippi"
"25" "Missouri"
"26" "Montana"
"27" "Nebraska"
"28" "Nevada"
"29" "New Hampshire"
"30" "New Jersey"
"31" "New Mexico"
"32" "New York"
"33" "North Carolina"
"34" "North Dakota"
"35" "Ohio"
"36" "Oklahoma"
"37" "Oregon"
"38" "Pennsylvania"
"39" "Rhode Island"
"40" "South Carolina"
"41" "South Dakota"
"42" "Tennessee"
"43" "Texas"
"44" "Utah"
"45" "Vermont"
"46" "Virginia"
"47" "Washington"
"48" "West Virginia"
"49" "Wisconsin"
"50" "Wyoming"
end
rename state1 statefips
save state_mapping.dta, replace
restore

* Load the state mapping data (with string statefips)
merge m:1 statefips using state_mapping.dta
* Check the merge results
tab _merge

* Drop the merge indicator (_merge)
drop _merge
*/

// ------------------- GENDER AND RACE -------------------
destring sex_ref, replace
recode sex_ref (2 = 1)(1 = 0), gen(female_ref)
label define sexlbl 0 "male" 1 "female"
label values female_ref sexlbl

destring race2, replace
rename race2 race_spouse
label values race_spouse race

// ------------------- FAMILY STRUCTURE -------------------
gen single_fem = (fam_type == 7)
label define femparent 0 "not single mother" 1 "single mother"
label values single_fem femparent
label variable single_fem "Single Mother"

gen single_mal = (fam_type == 6)
label define malparent 0 "not single father" 1 "single father"
label values single_mal malparent
label variable single_mal "Single Father"

// ------------------- CHILD AGE STRUCTURE -------------------
destring childage, replace
label define childage_lbl ///
0 "No children" 1 "Oldest <6" 2 "Oldest 6-11 + <6" 3 "All 6-11" ///
4 "Oldest 12-17 + <12" 5 "All 12-17" 6 "Oldest >17 + <17" 7 "All >17"
label values childage childage_lbl

// ------------------- INCOME RANK -------------------
sum inc_rank, meanonly
replace inc_rank = r(mean) if missing(inc_rank)

// ------------------- OBESITY PREVALENCE -------------------
*------------- OBESITY PREVALENCE USING A LOOP ----------------*
gen obesity = .

* Define a matrix of state-obesity pairs
input ///
byte statecode float obesityval
1 36.1
2 30.5
4 31.4
6 0 // California dropped earlier
8 23.8
9 29.1
10 34.4
11 23.8
12 27.0
13 33.1
16 29.5
17 31.6
18 35.3
19 33.9
20 35.2
21 36.5
22 35.9
23 31.7
24 32.3
25 25.2
26 36.0
27 30.1
28 40.8
29 34.8
30 28.3
31 34.1
32 30.6
33 31.8
34 26.3
35 31.7
36 27.1
37 34.0
38 34.8
39 34.8
40 36.8
41 29.0
42 33.2
44 30.0
45 35.4
46 33.0
47 36.5
48 34.0
49 29.2
50 26.6
51 31.9
53 28.3
54 28.3
55 34.2
56 29.7
end

tostring statecode, gen(statecode_str) format(%02.0f)

* Loop through and assign obesity values
quietly {
    forvalues i = 1/`=_N' {
        local s = statecode_str[`i']   // now it's a string with leading zeros
        local o = obesityval[`i']
        replace obesity = `o' if state == "`s'"  // match the string statecode
    }
}

// ------------------- FILTER SAMPLE -------------------
keep if !missing(fdhomecq) & !missing(fdhomepq)
drop if missing(state) | state == "06"  // Drop if state missing or California (already treated)

// ------------------- POLICY VARIABLES -------------------
* Initialize the new variables
gen eitc_expanded = 0
gen eitc_refundable = 0
gen eitc_nonrefundable = 0

* Create a variable called state_name with state names 
gen state_name = ""
replace state_name = "Alabama" if state == "01"
replace state_name = "Alaska" if state == "02"
replace state_name = "Arizona" if state == "04"
replace state_name = "Arkansas" if state == "05"
replace state_name = "California" if state == "06"
replace state_name = "Colorado" if state == "08"
replace state_name = "Connecticut" if state == "09"
replace state_name = "Delaware" if state == "10"
replace state_name = "District of Columbia" if state == "11"
replace state_name = "Florida" if state == "12"
replace state_name = "Georgia" if state == "13"
replace state_name = "Hawaii" if state == "15"
replace state_name = "Idaho" if state == "16"
replace state_name = "Illinois" if state == "17"
replace state_name = "Indiana" if state == "18"
replace state_name = "Iowa" if state == "19"
replace state_name = "Kansas" if state == "20"
replace state_name = "Kentucky" if state == "21"
replace state_name = "Louisiana" if state == "22"
replace state_name = "Maine" if state == "23"
replace state_name = "Maryland" if state == "24"
replace state_name = "Massachusetts" if state == "25"
replace state_name = "Michigan" if state == "26"
replace state_name = "Minnesota" if state == "27"
replace state_name = "Mississippi" if state == "28"
replace state_name = "Missouri" if state == "29"
replace state_name = "Montana" if state == "30"
replace state_name = "Nebraska" if state == "31"
replace state_name = "Nevada" if state == "32"
replace state_name = "New Hampshire" if state == "33"
replace state_name = "New Jersey" if state == "34"
replace state_name = "New Mexico" if state == "35"
replace state_name = "New York" if state == "36"
replace state_name = "North Carolina" if state == "37"
replace state_name = "North Dakota" if state == "38"
replace state_name = "Ohio" if state == "39"
replace state_name = "Oklahoma" if state == "40"
replace state_name = "Oregon" if state == "41"
replace state_name = "Pennsylvania" if state == "42"
replace state_name = "Rhode Island" if state == "44"
replace state_name = "South Carolina" if state == "45"
replace state_name = "South Dakota" if state == "46"
replace state_name = "Tennessee" if state == "47"
replace state_name = "Texas" if state == "48"
replace state_name = "Utah" if state == "49"
replace state_name = "Vermont" if state == "50"
replace state_name = "Virginia" if state == "51"
replace state_name = "Washington" if state == "53"
replace state_name = "West Virginia" if state == "54"
replace state_name = "Wisconsin" if state == "55"
replace state_name = "Wyoming" if state == "56"

* States with Refundable EITCs
replace eitc_expanded = 1 if state_name == "Connecticut" & year == 2011
replace eitc_expanded = 1 if state_name == "Oregon" & inlist(year, 2005, 2014, 2016)
replace eitc_expanded = 1 if state_name == "Colorado" & year == 2015
replace eitc_expanded = 1 if state_name == "Hawaii" & year == 2017
replace eitc_expanded = 1 if state_name == "Montana" & year == 2017
replace eitc_expanded = 1 if state_name == "South Carolina" & year == 2018
replace eitc_expanded = 1 if state_name == "California" & inrange(year, 2015, 2020)
replace eitc_expanded = 1 if state_name == "New Jersey" & inlist(year, 2008, 2015, 2016, 2018, 2019)
replace eitc_expanded = 1 if state_name == "Maryland" & inlist(year, 2005, 2014)
replace eitc_expanded = 1 if state_name == "Delaware" & year == 2005
replace eitc_expanded = 1 if state_name == "New York" & year == 2008
replace eitc_expanded = 1 if state_name == "Massachusetts" & inlist(year, 2015, 2018)
replace eitc_expanded = 1 if state_name == "District of Columbia" & inlist(year, 2008, 2014)
replace eitc_expanded = 1 if state_name == "Illinois" & inlist(year, 2012, 2017)

* Assign Refundable EITC for states with refundable credits
replace eitc_refundable = 1 if state_name == "Connecticut" & year >= 2011
replace eitc_refundable = 1 if state_name == "Oregon" & inlist(year, 2005, 2014, 2016)
replace eitc_refundable = 1 if state_name == "California" & inrange(year, 2015, 2020)
replace eitc_refundable = 1 if state_name == "New Jersey" & inlist(year, 2008, 2015, 2016, 2018, 2019)
replace eitc_refundable = 1 if state_name == "Massachusetts" & inlist(year, 2015, 2018)
replace eitc_refundable = 1 if state_name == "Illinois" & inlist(year, 2012, 2017)

* States with Non-Refundable EITCs
replace eitc_nonrefundable = 1 if state_name == "Ohio" & year == 2013
replace eitc_nonrefundable = 1 if state_name == "North Carolina" & year == 2007


* STEP 1: Create variable for first EITC expansion year per state
gen eitc_exp_year = .

bysort state (year): replace eitc_exp_year = year if eitc_expanded == 1 & missing(eitc_exp_year)

* Fill in first expansion year for each state
bysort state (year): replace eitc_exp_year = eitc_exp_year[_n-1] if missing(eitc_exp_year)

* STEP 2: Create a post-treatment indicator
gen eitc_post = 0
replace eitc_post = 1 if !missing(eitc_exp_year) & year >= eitc_exp_year

* STEP 3: Create event time variable (relative to expansion)
gen eitc_event_time = .
replace eitc_event_time = year - eitc_exp_year if !missing(eitc_exp_year)

// ------------------- EDUCATION -------------------
//destring educ_ref educa2, replace
gen atleasthighschl = educ_ref >= 13
//gen atleastcoll = educ_ref >= 14

// Convert numeric to string variables and clean up missing values
//destring educa2, replace
destring educ_ref, replace
destring asian, replace
destring jfs_amt, replace
destring fssix, replace

// Create atleasthighschl variable (1 for at least high school, 0 otherwise)
//gen atleasthighschl = (educ_ref >= 15 & educa2 >= 15)

// Create atleastcoll variable (1 for at least college, 0 otherwise)
gen atleastcoll = (educ_ref >= 14)

// Create atleast2child variable (1 for at least 2 children, 0 otherwise)
gen atleast2child = !(nochild == 1 | onechild == 1)

// Create coll and nocoll variables based on education reference
gen coll = inlist(educ_ref, 14, 15, 16)
gen nocoll = !coll

// Create nocol_child and nocoll_child_FedShr variables
gen nocol_child = coll == 0 & nochild == 0
gen nocoll_child_FedShr = nocol_child * eitc_state

// Clean missing values
replace jfs_amt = 0 if jfs_amt == .
replace fssix = 0 if fssix == .

// Create atlsths_child variable (1 if no children and at least high school, 0 otherwise)
gen atlsths_child = (atleasthighschl == 0 & nochild == 0)

// Global variable lists for model specifications
global ylist "ratio_fdhmpq ratio_fdhmcq ratio_fdawypq ratio_fdawycq tfoodtop tfoodtoc tfoodawp tfoodawc alcbevcq alcbevpq talcbevc tobacccq"
global xlist "HasIncomeTax gov_party FedShare chdtx_cy single_fem single_mal marital1 RURAL region female_ref childage nochild onechild twochild persot64 atleast3child age_ref earncomp jfs_amt fsalarym urate povrate tottxpdx Minwage childpov states_percapinc"
global xlist_new "seitc_cy FedShare age_ref fam_size below25 btw25_35 btw35_45 btw45_55 btw55_65 educ_ref white1 black asian native_america multirace married1 wid_div_sep nevr_married1 less_20k btw_20k_50k btw_50k_80k above_80k nochild onechild twochild atleast3child jfs_amt urate povrate seitc ln_fdawy ratio_fdawycq "
global xlist1 "FedShare HasIncomeTax gov_party DemControl single_fem single_mal married1 wid_div_sep nevr_married1 nochild onechild twochild atleast3child earncomp fsalarym"
global xlist2 "age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 RURAL persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate governor_dem minwage_fed minwage_state gsp"
global xlist3 "HasIncomeTax age_ref educ_ref fam_size single_fem single_mal married RURAL female_ref nochild onechild twochild atleast3child white persot64 hlthincq earncomp jfs_amt fssix fsalarym medsrvcq predrgcq entertcq urate povrate MOE Minwage states_percapinc"
global xlist4 "HasIncomeTax age_ref educ_ref fam_size single_fem single_mal married RURAL female_ref nochild onechild twochild atleast3child white persot64 hlthincq earncomp jfs_amt fssix fsalarym medsrvcq predrgcq entertcq urate povrate MOE Minwage states_percapinc"
global xlist5 "HasIncomeTax age_ref fam_size single_fem single_mal married RURAL female_ref nochild onechild twochild atleast3child white persot64 hlthincq earncomp jfs_amt fssix fsalarym medsrvcq predrgcq tentrmnc entertcq alcbevcq talcbevc tobacccq urate povrate obesity MOE Minwage states_percapinc"
global xlist7 "state seitc_cy FedShare HasIncomeTax DemControl age_ref fam_size female_ref single_fem nochild onechild twochild atleast3child white persot64 RURAL jfs_amt fssix fsalarym predrgcq fdhomecq fdawaycq ratio_fdhmpq ratio_fdawypq tfoodawc urate povrate MOE Minwage states_percapinc"
global xlist6 "HasIncomeTax age_ref single_fem single_mal married female_ref nochild onechild twochild atleast3child white persot64 hlthincq earncomp RURAL jfs_amt fssix fsalarym medsrvcq predrgcq tentrmnc entertcq urate povrate MOE Minimum_wage states_percapinc"
global xlist9 "HasIncomeTax age_ref fam_size single_fem single_mal married RURAL female_ref nochild onechild twochild atleast3child white persot64 hlthinpq earncomp jfs_amt fssix fsalarym medsrvpq predrgpq tentrmnc entertpq urate povrate MOE Minwage states_percapinc"
global xlist2c "HasIncomeTax age_ref fam_size single_fem single_mal married RURAL female_ref white persot64 hlthincq earncomp jfs_amt fssix fsalarym medsrvcq predrgcq entertcq urate povrate MOE Minwage states_percapinc"
global xlist2r "HasIncomeTax age_ref fam_size single_fem single_mal married RURAL female_ref persot64 hlthincq earncomp jfs_amt fssix fsalarym medsrvcq predrgcq entertcq urate povrate MOE Minwage states_percapinc"
global xlist2a "HasIncomeTax fam_size single_fem single_mal married RURAL female_ref nochild onechild twochild atleast3child white persot64 hlthincq earncomp jfs_amt fssix fsalarym medsrvcq predrgcq entertcq urate povrate MOE"
global xlist_new "eitc_state_refundable eitc_state age_ref educ_ref coll fam_size educ_ref white1 black native_america multirace married1 wid_div_sep nevr_married1 less_20k btw_20k_50k btw_50k_80k above_80k nochild onechild twochild atleast3child jfs_amt eatout fdhomecq ratio_fdhmcq eatin fdawaycq ratio_fdawycq "
global xlist2_lbr "HasIncomeTax age_ref educ_ref white1 black asian native_america multirace fam_size married1 wid_div_sep nevr_married1 RURAL region nochild onechild twochild atleast3child persot64 hlthincq jfs_amt fssix less_20k btw_20k_50k btw_50k_80k above_80k urate povrate obesity MOE Minwage states_percapinc"
global xlist2_hlthins "HasIncomeTax age_ref white1 black asian native_america multirace educ_ref fam_size married1 wid_div_sep nevr_married1 RURAL region nochild onechild twochild atleast3child persot64 earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k above_80k urate povrate obesity MOE Minwage states_percapinc"
global xlist2_married "HasIncomeTax age_ref white1 black asian native_america multirace educ_ref fam_size RURAL region nochild onechild twochild atleast3child persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k above_80k urate povrate obesity MOE Minwage states_percapinc"

* Encode state names to numeric for interaction terms and clustering
encode state_name, gen(state_name_id)
tab state_name_id state_name  // Verify correct encoding

// Creating the ever_treated Dummy in Stata
gen ever_treated = 0
bysort state_name_id (year): replace ever_treated = 1 if ///
    sum(eitc_state > 0) > 0



// Descriptive statistics by treatment groups (expansion vs non-expansion)
qui eststo noexpan: qui estpost sum $xlist_new if ever_treated == 0 
qui eststo expan: qui estpost sum $xlist_new if  ever_treated == 1
qui eststo noexpan_full: qui estpost sum $xlist_new if ever_treated == 1 & eitc_expanded == 0
qui eststo expan_full: qui estpost sum $xlist_new if ever_treated == 1 & eitc_expanded == 1 
qui eststo all: qui estpost sum $xlist_new 


// Output statistics to RTF file
esttab all noexpan expan noexpan_full expan_full using sumstats2.rtf, replace star(* 0.1 ** 0.05 *** 0.01) r2 ar2 p label scalar(F p_value) cells("mean(pattern(1 1 1 1) fmt(4)) b(star pattern(0 0 1) fmt(2))" "sd(pattern(1 1 1) par) t(pattern(0 0 0) par)") collabels(none)

* ------------------------------------------------------------
* TWFE model: Regressions on food away from home (eatout)
* ------------------------------------------------------------


* Model 1: eatout
reg eatout eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate i.qintrvmo i.state_name_id i.year [pweight = finlwt21], cluster(state_name_id)
outreg2 using secondstage.doc, replace ctitle(model1)
display "AIC = " -2*e(ll) + 2*e(df_m)
display "BIC = " -2*e(ll) + e(df_m)*ln(e(N))

* Model 2: ln_fdawy
reg ln_fdawy eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate i.qintrvmo i.state_name_id i.year [pweight = finlwt21], cluster(state_name_id)
outreg2 using secondstage.doc, append ctitle(model2)
display "AIC = " -2*e(ll) + 2*e(df_m)
display "BIC = " -2*e(ll) + e(df_m)*ln(e(N))

* Model 3: ratio_fdawycq
reg ratio_fdawycq eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate i.qintrvmo i.state_name_id i.year [pweight = finlwt21], cluster(state_name_id)
outreg2 using secondstage.doc, append ctitle(model3)
display "AIC = " -2*e(ll) + 2*e(df_m)
display "BIC = " -2*e(ll) + e(df_m)*ln(e(N))

* Model 4: eatout with state trends
reg eatout eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate c.year#i.state_name_id i.qintrvmo i.state_name_id i.year [pweight = finlwt21], cluster(state_name_id)
outreg2 using secondstage.doc, append ctitle(model4)
display "AIC = " -2*e(ll) + 2*e(df_m)
display "BIC = " -2*e(ll) + e(df_m)*ln(e(N))

* Model 5: ln_fdawy with state trends
reg ln_fdawy eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate c.year#i.state_name_id i.qintrvmo i.state_name_id i.year [pweight = finlwt21], cluster(state_name_id)
outreg2 using secondstage.doc, append ctitle(model5)
display "AIC = " -2*e(ll) + 2*e(df_m)
display "BIC = " -2*e(ll) + e(df_m)*ln(e(N))

* Model 6: ratio_fdawycq with state trends
reg ratio_fdawycq eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate c.year#i.state_name_id i.qintrvmo i.state_name_id i.year [pweight = finlwt21], cluster(state_name_id)
outreg2 using secondstage.doc, append ctitle(model6)
display "AIC = " -2*e(ll) + 2*e(df_m)
display "BIC = " -2*e(ll) + e(df_m)*ln(e(N))



* ------------------------------------------------------------
* TWFE regressions: Food at home
* ------------------------------------------------------------

* Model 1: Level of food at home expenditure
reg eatin eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate i.qintrvmo i.year i.state_name_id ///
    [pweight=finlwt21], cluster(state_name_id)
outreg2 using reduced.doc, replace ctitle(Model 1)

* Model 2: Log of food at home expenditure
qui reg ln_fdhm eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate i.qintrvmo i.year i.state_name_id ///
    [pweight=finlwt21], cluster(state_name_id)
outreg2 using reduced.doc, append ctitle(Model 2)

* Model 3: Expenditure share of food at home
qui reg ratio_fdhmcq eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate i.qintrvmo i.year i.state_name_id ///
    [pweight=finlwt21], cluster(state_name_id)
outreg2 using reduced.doc, append ctitle(Model 3)

* Model 4: Add state-specific time trends
qui reg eatin eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate c.year#i.state_name_id i.qintrvmo i.year i.state_name_id ///
    [pweight=finlwt21], cluster(state_name_id)
outreg2 using reduced.doc, append ctitle(Model 4)

* Model 5: Log food at home with state trends
qui reg ln_fdhm eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate c.year#i.state_name_id i.qintrvmo i.year i.state_name_id ///
    [pweight=finlwt21], cluster(state_name_id)
outreg2 using reduced.doc, append ctitle(Model 5)

* Model 6: Expenditure share with state trends
reg ratio_fdhmcq eitc_state age_ref white1 black native_america multirace fam_size wid_div_sep nevr_married1 bls_urbn persot64 hlthincq earncomp jfs_amt fssix less_20k btw_20k_50k btw_50k_80k urate povrate c.year#i.state_name_id i.qintrvmo i.year i.state_name_id ///
    [pweight=finlwt21], cluster(state_name_id)
outreg2 using reduced.doc, append ctitle(Model 6)

* ------------------------------------------------------------

* CALLAWAY & SANT'ANNA regressions: Food at home
* 
// Step 0: Preserve original data
preserve

// Step 2: Collapse to one observation per state-year
collapse (mean) fdawaycq fdhomecq foodcq ratio_fdawycq ratio_fdhmcq eitc_state eitc_exp_year [pweight=finlwt21], by(state_name_id year)
sum
tab state_name_id
 eitc_exp_year
// Step 1: Check for duplicate state-year combinations
duplicates report state_name_id year
duplicates list state_name_id year

// Step 3: Run csdid
csdid fdawaycq eitc_state, ivar(state_name_id) time(year) gvar(eitc_exp_year)

// Step 4: Restore original dataset
restore

gen eitc_exp_year = .
gen ever_treated = 0

* Mark first treatment year
bysort state_name_id (year): replace eitc_exp_year = year if eitc == 1 & eitc[_n-1]==0
bysort state_name_id (year): replace eitc_exp_year = eitc_exp_year[_n-1] if missing(eitc_exp_year)

* Optional: mark ever-treated states
gen ever_treated = 1 if !missing(eitc_exp_year)


------------------------------------------------------------
csdid foodcq, ivar(state_name_id) time(year) gvar(eitc_exp_year)
recode eitc_exp_year (.=0)
* Model 1: Callaway & Sant'Anna for the treatment effect
csdid ln_fdhm (eitc_state), time(year) ivar(state_name_id) gvar(eitc_exp_year) method(dripw) 
outreg2 using secondstage.doc, replace ctitle(model1)



gen high_eitc = eitc if generosity >= threshold
gen low_eitc = eitc if generosity < threshold

csdid foodcq, ivar(state_name_id) time(year) gvar(eitc_exp_year) ///
    groupvar(high_eitc) method(ipw)

	
	estat event, window(-5 5) ///
    graphopts(title("Event Study Estimates: EITC Expansion") ytitle("ATT"))
