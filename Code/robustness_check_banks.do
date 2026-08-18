/*******************************************************************************
* Title: robustness_check_banks
* Author: Mahima Sabberwal
* Date: April 2025

* Description: Regressing the number of banks in a region (from ICRISAT data) from 1981 - 1991, and 1976 - 1986 on the SSIV.

*******************************************************************************/

clear all
set more off, perm


********************************************************************************


* Importing bank data - first 1991-2001

import delimited "$subs_data/icrisat_banks_9101.csv", clear

xtset distcode year

* Lots of district codes with reported bank number as -1 for 1991
rename banksnumbernumber banks_number9101
bys distcode: drop if (year == 1991) & (banks_number == -1)

replace distname = trim(distname)
replace distname = lower(distname)
replace distname = subinstr(distname, " ", "", .)
replace distname = regexr(distname, "[0-9]+", "") // Removing numbers 

destring year, replace ignore(" ")

gen year1 = 0
replace year1 = 1 if (year == 1991)
replace year1 = 2 if (year == 2001)


save "$subs_data/icrisat_banks_9101.dta", replace


*****

* Importing 76 - 86

import delimited "$subs_data/icrisat_banks_7686.csv", clear

xtset distcode year

* Lots of district codes with reported bank number as -1 for 1991
rename banksnumbernumber banks_number7686

replace distname = trim(distname)
replace distname = lower(distname)
replace distname = subinstr(distname, " ", "", .)
replace distname = regexr(distname, "[0-9]+", "") // Removing numbers 

destring year, replace ignore(" ")

save "$subs_data/icrisat_banks_7686.dta", replace


bysort distname (year): gen obsnum = _n
bysort distname: gen n_obs = _N
tab n_obs

keep if (n_obs == 2)


gen year1 = 0
replace year1 = 1 if (year == 1976)
replace year1 = 2 if (year == 1986)


merge 1:1 distname year1 using "$subs_data/icrisat_banks_9101.dta"

keep if _merge == 3
drop _merge 

drop if (banks_number7686 == -1)

keep if (n_obs == 2)


save "$subs_data/icrisat_banks_9101.dta", replace


*********************************

use "$working_data/panel_states.dta", clear

keep if (education_category == 5)
drop education_category 

keep if rural == "Urban"
drop rural

replace district_name = subinstr(district_name, "district-", "", .)
rename district_name distname 

gen str50 distname_str = distname
gen str50 distname_temp = distname
drop distname
rename distname_temp distname
drop distname_str

label values year
label drop year_lbl

gen year1 = year
replace year1 = 1 if (year == 1)
replace year1 = 2 if (year == 2)


merge 1:1 distname year1 using "$subs_data/icrisat_banks_9101.dta"


***********************************

keep if _merge == 3
drop _merge

drop if n_obs == 1

************************************

xtset district_name_num year, delta(1)

xtreg shift_share_treat shift_share_instr sum_share_period, fe vce(cluster id_sd)


* Control for 1991 and 2001 populations in the 1976/86 regressions as a proxy for the populations, assuming scaled, does not change results significantly

* Regressions
eststo banks_9101: xtivreg banks_number9101 (shift_share_treat10 = shift_share_instr10) sum_share_period total_pop, fd vce(cluster id_sd)

eststo banks_7686: xtivreg banks_number7686 (shift_share_treat10 = shift_share_instr10) sum_share_period total_pop, fd vce(cluster id_sd)


esttab using "$output/Prelim output/banks_robustness.tex", replace ///
    b(3) se(3) se booktabs nomtitles frag ///
	starlevels(* 0.10 ** 0.05 *** 0.01) 











