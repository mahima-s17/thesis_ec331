/*******************************************************************************
* Title: analysis_graphs

* Author: Mahima Sabberwal
* Date: January 2025

* Description: Code to analyse final dataset panel_states. Construct descriptive graphs, run first stage and SSIV regressions

*******************************************************************************/

clear all
set more off, perm

ssc install estout
ssc install coefplot, replace 

* Globals
global working_data "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Clean data"
global output "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Output"
global subs_data "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Data"


use "$working_data/panel_states.dta", clear



********************************************************************************

* For QGIS: to make map

preserve 

keep if (district_code == "00" | district_name == "uttarakhandcompositeregion")
keep if (education_category == 5) & (rural == "Total")

keep district_name shift_share_instr year

encode district_name, gen(district_name_n)
xtset district_name_n year

gen shift_share_instr_diff = D.shift_share_instr

drop if missing(shift_share_instr_diff)
drop year shift_share_instr district_name_n


* To do properly: would get rid of these from Bihar and put in to Jharkhand --> Palamu, Hazaribagh, Sahibganj, Dhanbad and Giridih

export delimited using "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Data\qgis_amended.csv", replace

restore

* How to make a map in Stata


********************************************************************************
***** Descriptive graphs********************************************************

// Graph to show scatter of instrument and treatment variable values

preserve

keep if (education_category == 5)
keep if (rural == "Urban")

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

keep if (year == 2)

twoway scatter shift_share_instr shift_share_treat [fweight=total_pop], ///
	msymbol(circle_hollow) ///
	xtitle("Shift-share treatment value") ytitle("Shift-share instrument value") ///
	ylabel( ,angle(horizontal) format(%4.2f)) ///
	graphregion(color(white))

graph export "$output/Prelim output/instrument_scatter_urban.jpg", replace

restore 


**********

preserve

keep if (year == 2)

keep if (education == 5) & (rural == "Total")
* 426 observations, so when two time periods: 852 obs

twoway scatter shift_share_instr shift_share_treat, ///
	xtitle("Shift-share treatment value") ytitle("Shift-share instrument value") ///
	ylabel( ,angle(horizontal) format(%4.2f)) ///
	graphregion(color(white))

graph export "$output/Prelim output/instrument_scatter_filtered_total.jpg", replace

restore 


**********
// Histogram for instrument value 

preserve

keep if (education_category == 5) & (rural == "Total")

keep district_code state_code district_name shift_share_instr year

encode district_name, gen(district_name_n)
xtset district_name_n year

gen shift_share_instr_diff = D.shift_share_instr
gen diff_shift_share = abs(shift_share_instr_diff)

twoway hist diff_shift_share, bin(100) frequency ///
	xtitle("Change in shift-share instrument value (absolute)") ///
	title("Overall for all regions")

graph export "$output/Prelim output/hist_instrument_change.jpg", replace
	
restore


// Histogram for treatment value

preserve

keep if (education_category == 5) & (rural == "Total")

keep district_code state_code district_name shift_share_treat year

encode district_name, gen(district_name_n)
xtset district_name_n year

gen shift_share_treat_diff = D.shift_share_treat
gen diff_shift_share_treat = abs(shift_share_treat_diff)

twoway hist diff_shift_share_treat, bin(100) frequency ///
	xtitle("Change in shift-share treatment value (absolute)") ///
		title("Overall for all regions")

graph export "$output/Prelim output/hist_treatment_change.jpg", replace
	
restore




// Rural 
* Instrument 
preserve

keep if (education_category == 5) & (rural == "Rural")

keep district_code state_code district_name shift_share_instr year

encode district_name, gen(district_name_n)
xtset district_name_n year

gen shift_share_instr_diff = D.shift_share_instr
gen diff_shift_share = abs(shift_share_instr_diff)

twoway hist diff_shift_share, bin(100) frequency ///
	xtitle("Change in shift-share instrument value (absolute)") ///
	title("Rural parts of regions")
	
graph export "$output/Prelim output/hist_rural_inst_change.jpg", replace
	
restore


* Treatment
preserve

keep if (education_category == 5) & (rural == "Rural")

keep district_code state_code district_name shift_share_treat year

encode district_name, gen(district_name_n)
xtset district_name_n year

gen shift_share_treat_diff = D.shift_share_treat
gen diff_shift_share_treat = abs(shift_share_treat_diff)

twoway hist diff_shift_share_treat, bin(100) frequency ///
	xtitle("Change in shift-share treatment value (absolute)") ///
		title("Rural parts of regions")

restore



// Urban
* Instrument
preserve

keep if (education_category == 5) & (rural == "Urban")

keep district_code state_code district_name shift_share_instr year

encode district_name, gen(district_name_n)
xtset district_name_n year

gen shift_share_instr_diff = D.shift_share_instr
gen diff_shift_share = abs(shift_share_instr_diff)

twoway hist diff_shift_share, bin(100) frequency ///
	xtitle("Change in shift-share instrument value (absolute)") ///
	title("Urban parts of regions")
	
graph export "$output/Prelim output/hist_urban_inst_change.jpg", replace
	
restore


* Treatment
preserve

keep if (education_category == 5) & (rural == "Urban")

keep district_code state_code district_name shift_share_treat year

encode district_name, gen(district_name_n)
xtset district_name_n year

gen shift_share_treat_diff = D.shift_share_treat
gen diff_shift_share_treat = abs(shift_share_treat_diff)

twoway hist diff_shift_share_treat, bin(100) frequency ///
	xtitle("Change in shift-share treatment value (absolute)") ///
		title("Urban parts of regions")

restore



********************************************************************************
********************************************************************************



// BAR CHART TO SHOW INDUSTRY WORKERS BY GENDER: I want to see whether men and women tend to disproportionately work in different industries. PLot change in tariffs over bar


preserve

keep if (education_category == 5)
keep if (rural == "Urban")

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year

* Didn't generate other services gender share so need to:
gen other_services_fshare = (other_service_female / main_pop_total)
gen other_services_mshare = (other_service_male / main_pop_total) 


* Gen proportion of each industry which is female 
rename cultivators_total cultivator_total

* Renaming tariff vars
rename manufacturing_tariff manu_industry_tariff
rename wholesale_trade_tariff trade_tariff
rename housing_manu_tariff household_tariff
rename manufacturing_1997_tariff manu_industry_1997_tariff
rename wholesale_trade_1997_tariff trade_1997_tariff
rename housing_manu_1997_tariff household_1997_tariff

gen other_service_tariff = 0
gen other_service_1997_tariff = 0

* For each industry, generating 1) share of female workers in a particular industry (out of total workers), 2) share of particular industry that was female 
foreach v in cultivator agriculture livestock mining manu_industry construction transport trade household other_service {
	*gen `v'_fworkershare = `v'_female / main_pop_female
	*gen `v'_mworkershare = `v'_male / main_pop_male
	gen proportion_female_`v' = (`v'_female / `v'_total)
	gen prbaseline_female_`v' = proportion_female_`v' if (year == 1)
	replace prbaseline_female_`v' = prbaseline_female_`v'[_n-1] if missing(prbaseline_female_`v')
	rename `v'_tariff tariff_`v'
	rename `v'_1997_tariff tariff_1997_`v'
}

* Currently, out of all the women working, 44 % are in other services. I control for the effect this has on employment.

**# Bookmark #3

/* Want the bar to plot for 1991 baseline female proportions (female-specific exposure)
So plotting the means for each industry*/

* Reshaping data so easier to plot graph
collapse (mean) proportion_female_* prbaseline_female_* tariff_*, by (year)


* Reshaping is being a bit fussy so let's rename to have numbers after the stubs 
local i = 1
foreach industry in cultivator agriculture livestock mining manu_industry construction transport trade household other_service {
	rename proportion_female_`industry' proportion_female`i'
	rename prbaseline_female_`industry' prbaseline_female`i'
	rename tariff_`industry' tariff`i'
	rename tariff_1997_`industry' tariff_1997`i'
	local i = `i' + 1
}	

reshape long tariff tariff_1997 proportion_female prbaseline_female, i(year) j(industry)

label define industry_lbl 1 "Cultivator" 2 "Agriculture" 3 "Livestock" 4 "Mining" 5 "Manufacturing" 6 "Construction" 7 "Transport" 8 "Trade" 9 "House manuf" 10 "Other service"
label values industry industry_lbl

decode industry, gen(industry_str)

* Resetting panel to calculate the differences in tariffs by industries
xtset industry year

gen tariff_diff = D.tariff
gen tariff_1997_diff = D.tariff_1997

replace tariff_diff = -1 * (tariff_diff)
replace tariff_1997_diff = -1 * (tariff_1997_diff)

replace tariff_diff = tariff_diff[_n+1] if missing(tariff_diff)
replace tariff_1997_diff = tariff_1997_diff[_n+1] if missing(tariff_1997_diff)

gen proportion_tariff_change = 0 
replace proportion_tariff_change = (tariff_1997_diff / tariff) if (year == 1)

* Plotting as a proportion of the initial tariff



keep if (year == 1)


* Bar chart with baseline female proportions in industry and changes in tariffs from 1991 to 1997 


twoway (bar prbaseline_female industry, barwidth(0.5) yaxis(1) color(lavender)) ///
	   (line proportion_tariff_change industry, sort lwidth(medium) yaxis(2)), ///
	   xlabel(1(1)10, valuelabel angle(45)) ///
	   ytitle("Mean proportion of female workers in 1991") ///
	   ytitle("Reduction in tariffs as proportion, 1991 - 1997", axis(2)) ///
	   xtitle("Industry group") ///
	   graphregion(color(white)) ///
	   legend(off)
 
graph export "$output/Prelim output/bars_femaleshare_tariffchange.jpg", replace



********************************************************************************

// Histogram - whether industries with higher shocks concentrated in areas with larger change in employment for other reasons (residual)

* Start wuth regular employment 

preserve 

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

keep if (education == 5)
keep if (rural == "Urban") 

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year

eststo all_employment: xtivreg employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)
predict yhat, xb
gen resid = employment_disc - yhat 

* This might be more for if assuming exogeneity of the shares?

scatter resid livestock_baseline_share
scatter resid manu_industry_baseline_share
scatter resid trade_baseline_share 
scatter resid construction_baseline_share


* This isn't actually the full assumption I really need - so maybe it might be ok - the interaction on tariff and baseline share less 

gen livestock_interaction = livestock_baseline_share * livestock_1997_tariff
gen manu_interaction = manu_industry_baseline_share * manufacturing_1997_tariff
gen trade_interaction = trade_baseline_share * wholesale_trade_1997_tariff

scatter resid livestock_interaction
scatter resid manu_interaction
scatter resid trade_interaction

* These aren't sig - manufacturing maybee just slightly 

restore 









