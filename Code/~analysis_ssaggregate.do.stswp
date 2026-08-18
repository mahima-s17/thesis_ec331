/*******************************************************************************
* Title: analysis_ssaggregate

* Date: March 2025
* Author: Mahima Sabberwal

* Description: Uses the ssaggregate package to transform the dataset from location-level to industry-level, in order to calculate exposure-robust standard errors.

*******************************************************************************/

clear all
set more off, perm

ssc install estout
ssc install coefplot, replace 
ssc install ssaggregate 

* Globals
global working_data "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Clean data"
global output "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Output"
global subs_data "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Data"


********************************************************************************


// SSAGGREGATE PACKAGE - COMPUTING EXPOSURE ROBUST STANDARD ERRORS

/* Some notes on ssaggregate: ssaggregate package transforms dataset from location-level to industry-level: creates industry-level aggregates for SSIV 
--> it's computing the share-weighted average across locations for each variable

Running the regressions at the industry-level provides identical coefficients, but corrects standard errors to be exposure-robust
My location-level dataset is in the 'wide exposure' format (unique rows for location and columns for industry)

Note: no information on industry shocks is used in the execution of ssaggregate; once run, merge shocks and any industry-level controls to the aggregated dataset. In the industry-level regression, instrument treatment with the shock alone */


use "$working_data/panel_states.dta", clear

preserve 

* Sample restriction - same as standard above analysis
keep if (education_category == 5)
keep if (rural == "Urban")

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

* Renaming baseline share vars so that have common starting stub
local i = 1
foreach industry in cultivator agriculture livestock mining manu_industry construction transport trade household {
	rename `industry'_baseline_share baseline_share`i'
	local i = `i' + 1
}

gen sum_share = baseline_share1 + baseline_share2 + baseline_share3 + baseline_share4 + baseline_share5 + baseline_share6 + baseline_share7 + baseline_share8 + baseline_share9

* Keeping the variables I need
keep state_code district_code district_name shift_share_treat shift_share_instr fshift_share_treat mshift_share_treat sum_share_period employment_disc male_employment_disc female_employment_disc married_wshare1519 birth_share2024 year district_name_num id_sd baseline_*


* Dropping singleton observations - groups with only one observation at level of aggregation (?)


* (for now ignoring ln_outcomes, also gendered split IV)
local outcomes employment_disc male_employment_disc female_employment_disc married_wshare1519 birth_share2024

/* Controlling for sum of baseline shares: 
My missing industry (other services) is assigned a tariff of 0 and not subject to the shock, hence I do not want to include it in my estimating sample - why 'addmissing' is not included as an option - I sufficiently control for the sum of shares. */
ssaggregate `outcomes' shift_share_instr shift_share_treat fshift_share_treat mshift_share_treat, ///
n("ind_id") t(year) s(baseline_share) absorb("district_name_num year") ///
controls("sum_share")

drop if missing(ind_id)

* Note: ssaggregate creates the 'shock identifier' - n, which is the observation marker in the new dataset. Not in my case currently, but if you include multiple sets of controls - i.e. control 1 "..." control 2 "...", computes the residualised variables multiple times

* Relabelling ind_id var: string option in n identifier hasn't worked
label define ind_id_lbl 1 "cultivator" 2 "agriculture" 3 "livestock" 4 "mining" 5 "manu_industry" 6 "construction" 7 "transport" 8 "trade" 9 "household"
label values ind_id ind_id_lbl


save "$working_data/transformed.dta", replace

restore


**********
// Constructing shock dataset to be in line with transformed ssaggregate data - loading up WITS tariff data

cd "$subs_data"

use wits_tariff, clear

* Reshape back to long - so each row is an industry and we have industry identifiers
* But first, need to add in duplicate agriculture category (for ease in earlier cleaning code, I did this later)
gen agriculture_tariff = cultivator_tariff
gen agriculture_1997_tariff = cultivator_1997_tariff 

* Changing stub name 
local i = 1
foreach industry in cultivator agriculture livestock mining manufacturing construction transport wholesale_trade housing_manu {
	rename `industry'_tariff tariff`i'
	rename `industry'_1997_tariff tariff_1997`i'
	local i = `i' + 1
}

reshape long tariff tariff_1997, i(year) j(ind_id) string

* Now set tariff_1997 values to be tariff's values for 1991
replace tariff_1997 = tariff if missing(tariff_1997)

* Reclassifying and labelling ind_id so matches with transformed dataset
encode(ind_id), gen(ind_id_num)
drop ind_id
rename ind_id_num ind_id

label define ind_id_lbl 1 "cultivator" 2 "agriculture" 3 "livestock" 4 "mining" 5 "manu_industry" 6 "construction" 7 "transport" 8 "trade" 9 "household" 10 "missing - other services"
label values ind_id ind_id_lbl

* Recoding year to match with transformed.dta
gen year_coded = .
replace year_coded = 1 if year == 1991
replace year_coded = 2 if year == 2001

drop year
rename year_coded year
label define year_lbl 1 "1991" 2 "2001"
label values year year_lbl


tempfile industry_shock
save `industry_shock'


**********
// Merging
use "$working_data/transformed.dta", clear

merge 1:1 ind_id year using `industry_shock'

save "$working_data/transformed.dta", replace 




********************************************************************************

* Conducting exposure-robust analysis 

use "$working_data/transformed.dta", clear



// Herfindahl index

gen s_squared = (s_n)^2

gen sum_s_squared = sum(s_n)^2


********************************************************************************



// Industry-level first-stage regressions - but first-stage has f-stat of 3.10: - there is something you need to sort out with ssaggregate

reg shift_share_treat tariff_1997 year, r


* Use the shock as the instrument (the variable with 1991 and 1997 tariffs by industry, since the assumption of shocks being as-good-as-randomly assigned to industries still needs to be fulfilled.

ivregress 2sls employment (shift_share_treat = tariff_1997) year, r

ivregress 2sls male_employment (shift_share_treat = tariff_1997) year, r

ivregress 2sls female_employment (shift_share_treat = tariff_1997) year, r

ivregress 2sls married_wshare1519 (shift_share_treat = tariff_1997) year, r

ivregress 2sls birth_share2024 (shift_share_treat = tariff_1997) year, r









































