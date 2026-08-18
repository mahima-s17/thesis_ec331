/*******************************************************************************
* Title: clean_census

* Author: Mahima Sabberwal
* Date: November 2024

* Description: This do-file cleans, appends and merges together 1991 (2 tables for each state) and 2001 (2 tables for each state) datasets to have one clean dataset for all districts in all states. Add tariff data.


*******************************************************************************/

clear all
set more off, perm

ssc install reclink // package to help link district names together - similar to fuzzy matching in python


********************************************************************************
  ****************************************************************************
  
///// 1991 CLEANING /////


* Creating a program to do the same initial cleaning for all 1991 states' aggregate industry datasets - has cultivators and agricultural labourers but not main industry breakdon (formatting, renaming variables, constructing employment shares):

capture program drop process_dataset

program define process_dataset
    args dataset_name // Capturing dataset name passed to the program
    display "Processing dataset: `dataset_name'"

    * Importing dataset
    import delimited "$csv_1991/`dataset_name'.csv", clear
    save "$csv_1991/`dataset_name'.dta", replace
	
	* Renaming variables 
	rename v2 state_code
	rename v3 district_code
	rename v4 district_name
	rename v5 rural 
	label variable rural "Total/rural/urban"
	rename v6 education_level
	rename v7 total_pop
	rename v8 pop_male
	label variable pop_male "Total male population"
	rename v9 pop_female 
	label variable pop_female "Total female population"
	
	rename v10 main_pop_male
	label variable main_pop_male "Total number of males in main work"
	rename v11 main_pop_female
	label variable main_pop_female "Total number of females in main work"

	rename v12 cultivators_male
	rename v13 cultivators_female
	rename v14 agriculture_male
	rename v15 agriculture_female

	rename v16 manuf_house_male
	label variable manuf_house_male "Males working in manufacturing, processing, servicing and repairs in household industry"
	rename v17 manuf_house_female
	label  variable manuf_house_female "Females working in manufacturing, processing, servicing and repairs in household industry"

	rename v18 grouped_industry_male
	label variable grouped_industry_male "Males working in industry Group 4"
	rename v19 grouped_industry_female
	label variable grouped_industry_female "Females working in industry Group 4"

	* Fixing header/blanks: (mostly deleting first 10 rows and edu code at bottom)
	drop if (missing(state_code) & missing(district_code))
	drop v1
	* If v20 is not in the dataset - i.e. tamil nadu, program code is not halted
	capture drop v20
	drop in 1/2

	* Encoding or destringing all variables to be numeric (all strings initially):
	
	* Destringing variables:
	local vars_to_destring total_pop pop_male pop_female main_pop_male main_pop_female cultivators_male cultivators_female agriculture_male agriculture_female manuf_house_male manuf_house_female grouped_industry_male grouped_industry_female
	
	foreach var in `vars_to_destring' {
		destring `var', gen (`var'_des)
	drop `var'
	rename `var'_des `var'
	}
	
	* Generating a state_district id variable
	gen id_sd = state_code + district_code
	
	* Encoding education level to be a numeric label-value variable
	encode education_level, gen(education_level_num)
	drop education_level
	rename education_level_num education_level
	
	* Reordering to make later analysis easier
	local vars_ordered state_code district_code id_sd district_name rural education_level total_pop pop_male pop_female main_pop_male main_pop_female cultivators_male cultivators_female agriculture_male agriculture_female manuf_house_male manuf_house_female grouped_industry_male grouped_industry_female

order `vars_ordered'
	
	* Relabelling education 
	label define education_level_lbl 1 "Illiterate" 2 "Literate without education level" 3 "Primary" 4 "Middle" 5 "Matriculation/Secondary" 6 "Higher Secondary/Intermediate/Pre-U" 7 "Non-technical diploma" 8 "Technical diploma" 9 "Graduate and above" 10 "Total"
	label values education_level education_level_lbl
	
	* Generating total number of workers in each industry (currently by gender)
	gen main_pop_total = main_pop_male + main_pop_female
	gen cultivators_total = cultivators_male + cultivators_female
	gen agriculture_total = agriculture_male + agriculture_female
	gen manuf_house_total = manuf_house_male + manuf_house_female
	gen grouped_industry_total = grouped_industry_male + grouped_industry_female
	
	* Will now export individual shares of grouped industry - so can drop from this dataset - will keep manuf_house for now - robustness check for whether the figures match up across datasets 
	drop grouped_industry_male grouped_industry_female grouped_industry_total 
	
	* Now dropping manuf_house
	drop manuf_house_total manuf_house_male manuf_house_female
	
	* Saving changes to Stata dataset
	save "$csv_1991/`dataset_name'.dta", replace
	
end	

* Local for state names:
local states "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar_haveli daman_diu delhi lakshadweep pondicherry"

* Applying program to each state
foreach state in `states' {
    process_dataset "`state'_1991_main"
}


********************************************************************************

// ADDING IN DISAGGREGRATED MAIN WORKER CATEGORIES
clear all

* Creating a program which cleans the dataset for main industry workers broken down by industry group, merges this with the intitial dataset containing agricultural workers and cultivators, then constructs new employment shares

capture program drop industry_process 
program define industry_process 

    args dataset_name // Capturing dataset name passed to the program
    display "Processing dataset: `dataset_name'"

	import delimited "$csv_1991/`dataset_name'_1991_industry.csv", clear
	save "$csv_1991/`dataset_name'_1991_industry.dta", replace

	drop v1 v7 v8
	rename v2 state_code
	rename v3 district_code
	rename v4 district_name
	rename v5 rural
	rename v6 education_level

	rename v9 livestock_male
	rename v10 livestock_female
	rename v11 mining_male
	rename v12 mining_female
	rename v13 household_male
	rename v14 household_female
	rename v15 manu_industry_male
	rename v16 manu_industry_female
	rename v17 construction_male
	rename v18 construction_female
	rename v19 trade_male
	rename v20 trade_female
	rename v21 transport_male
	rename v22 transport_female 
	rename v23 other_service_male
	rename v24 other_service_female

	* Fixing header/blanks: (mostly deleting first 10 rows and edu code at bottom)
	drop if (missing(state_code) & missing(district_code))
	drop if _n <= 2

	* Dropping City/U.A observations - are not included in the dataset which has total population and includes agricultural labourers and cultivators, but total overall values for each district are the same
	drop if rural == "City:/U.A."		
			
	* Destringing selected variables - issue before:		
	local vars_destring livestock_male livestock_female mining_male mining_female household_male household_female manu_industry_male manu_industry_female construction_male construction_female trade_male trade_female transport_male transport_female other_service_male other_service_female

	* Destring the selected variables // there was an issue in just normally destringing - would not work, so force destring:
	foreach var in `vars_destring' {
		replace `var' = trim(`var')
		replace `var' = subinstr(`var', "**", "", .)
		destring `var', replace force
	}	

	* State/district ID:
	gen id_sd = state_code + district_code	
		
	* Encoding education level to be a numeric label-value variable
	encode education_level, gen(education_level_num)
	drop education_level
	rename education_level_num education_level

	* Recoding and relabelling education
	recode education_level (9 10 11 12 13 14 15 16 = 9) (17 = 10)
	* (recoding only changes the variable value for the observation - would not merge the observations )
	label define education_level_lbl 1 "Illiterate" 2 "Literate without education level" 3 "Primary" 4 "Middle" 5 "Matriculation/Secondary" 6 "Higher Secondary/Intermediate/Pre-U" 7 "Non-technical diploma" 8 "Technical diploma" 9 "Graduate and above" 10 "Total"
	label values education_level education_level_lbl

	* Merging together the observations for each state, district and rural/urban area with 'Graduate and above' - currently multiple 'grad and above' observations per area (separating different postgraduate courses):

	local vars_destring livestock_male livestock_female mining_male mining_female household_male household_female manu_industry_male manu_industry_female construction_male construction_female trade_male trade_female transport_male transport_female other_service_male other_service_female

	* Generating sum values for the industry shares for 'grad above', keeping the last one (total for each set of obs)
	foreach var in `vars_destring' {
		gen grad_above_`var' = 1 if (education_level == 9)
		gen sum_`var' = .
		bys state_code district_code district_name rural (grad_above_`var'): replace sum_`var' = sum(`var') if grad_above_`var' == 1
		by state_code district_code district_name rural (grad_above_`var'): egen maxsum_`var' = max(sum_`var') if grad_above_`var' == 1
	}
	
	* Have to manually put - does not work when part of the loop:
	* Only want to keep the observations for graduate and above where they take the max values: (note to self - easier way to do: collapse)
	by state_code district_code district_name rural: keep if (sum_livestock_male == maxsum_livestock_male)
	by state_code district_code district_name rural: keep if (sum_livestock_female == maxsum_livestock_female)
	by state_code district_code district_name rural: keep if (sum_mining_male == maxsum_mining_male)
	by state_code district_code district_name rural: keep if (sum_mining_female == maxsum_mining_female)
	by state_code district_code district_name rural: keep if (sum_trade_male == maxsum_trade_male)
	by state_code district_code district_name rural: keep if (sum_trade_female == maxsum_trade_female)	
	by state_code district_code district_name rural: keep if (sum_other_service_male == maxsum_other_service_male)
	by state_code district_code district_name rural: keep if (sum_manu_industry_male == maxsum_manu_industry_male)
	by state_code district_code district_name rural: keep if (sum_manu_industry_female == maxsum_manu_industry_female)
	by state_code district_code district_name rural: keep if (sum_transport_male == maxsum_transport_male)
	by state_code district_code district_name rural: keep if (sum_transport_female == maxsum_transport_female)
	by state_code district_code district_name rural: keep if (sum_other_service_female == maxsum_other_service_female)
	by state_code district_code district_name rural: keep if (sum_construction_male == maxsum_construction_male)
	by state_code district_code district_name rural: keep if (sum_construction_female == maxsum_construction_female)
	by state_code district_code district_name rural: keep if (sum_household_female == maxsum_household_female)
	by state_code district_code district_name rural: keep if (sum_household_male == maxsum_household_male)
	by state_code district_code district_name rural: keep if (sum_other_service_male == maxsum_other_service_male)	
	
	
	* Need to replace the prior industry workers with the maxsum ones for 'graduate above'
	local vars_destring livestock_male livestock_female mining_male mining_female household_male household_female manu_industry_male manu_industry_female construction_male construction_female trade_male trade_female transport_male transport_female other_service_male other_service_female

	foreach var in `vars_destring' {
		bys state_code district_code district_name rural education_level (grad_above_livestock_male): replace `var' = sum_`var' if (grad_above_livestock_male == 1)
	}

	drop grad_above_* sum_* maxsum_*
	
	duplicates drop
	
	* Can save tempfile without a unique name by state - Stata will temporarily store and then delete the tempfile after running each program
	tempfile state_industrytemp
	save `state_industrytemp'
	
	*** Merging:
	use "$csv_1991/`dataset_name'_1991_main.dta"

	merge 1:1 id_sd rural education_level using `state_industrytemp'
	
	save "$csv_1991/`dataset_name'_1991_merge.dta", replace
	
	* Constructing employment rates from new merged dataset - will compare
	
	use "$csv_1991/`dataset_name'_1991_merge.dta", clear
	
	gen livestock_total = livestock_male + livestock_female
	gen mining_total = mining_male + mining_female
	gen household_total = household_male + household_female
	gen manu_industry_total = manu_industry_male + manu_industry_female
	gen construction_total = construction_male + construction_female
	gen trade_total = trade_male + trade_female
	gen transport_total = transport_male + transport_female 
	gen other_service_total = other_service_male + other_service_female

	gen main_pop_total2 = cultivators_total + agriculture_total + livestock_total + mining_total + household_total + manu_industry_total + construction_total + trade_total + transport_total + other_service_total

	gen main_pop_male2 = cultivators_male + agriculture_male + livestock_male + mining_male + household_male + manu_industry_male + construction_male + trade_male + transport_male + other_service_male

	gen main_pop_female2 = cultivators_female + agriculture_female + livestock_female + mining_female + household_female + manu_industry_female + construction_female + trade_female + transport_female + other_service_female

	save "$csv_1991/`dataset_name'_1991_merge.dta", replace
	
end

	local states "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar_haveli daman_diu delhi lakshadweep pondicherry"

	* Applying program to each state
	foreach state in `states' {
		industry_process "`state'"
	}
	

********************************************************************************	
	
// ADDING NON-WORKER DATA TO DISCOUNT 1991	
	
* To calculate employment rates, will discount the total population denominator by dependents and pensioners, who classify as non-workers.

clear all

capture program drop non_worker_data
program define non_worker_data

    args dataset_name // Capturing dataset name passed to the program
    display "Processing dataset: `dataset_name'"

	import delimited "$csv_1991/`dataset_name'_1991_nonworker.csv", clear
	save "$csv_1991/`dataset_name'_1991_nonworker.dta", replace
	

	drop v1 v22 v23

	rename v2 state_code
	rename v3 district_code
	rename v4 district_name
	rename v5 rural	
	rename v6 age_group	
	rename v7 total_non_workers
	rename v8 male_non_workers
	rename v9 female_non_workers
	rename v10 household_nonworker_male
	rename v11 household_nonworker_female
	rename v12 students_nonworker_male 
	rename v13 students_nonworker_female
	rename v14 dependents_male 
	rename v15 dependents_female 
	rename v16 retired_male
	rename v17 retired_female
	rename v18 beggars_male
	rename v19 beggars_female
	rename v20 inmates_male
	rename v21 inmates_female 

	drop if missing(state_code) & missing(district_code)

	drop if _n <= 2

	* Only keeping totals, not disaggregated by age
	keep if (age_group == " TOTAL")
	drop age_group 

	* Destringing vars 
	local vars_destring_nw total_non_workers male_non_workers female_non_workers household_nonworker_male household_nonworker_female students_nonworker_male students_nonworker_female dependents_male dependents_female retired_male retired_female beggars_male beggars_female inmates_male inmates_female 

	* Destring the selected variables 
	foreach var in `vars_destring_nw' {
		replace `var' = trim(`var')
		replace `var' = subinstr(`var', "**", "", .)
		destring `var', replace force
		}	

	* Generating sums of populations to discount, then dropping - dependents and pensioners only
	gen non_worker_discount = dependents_male + dependents_female + retired_male + retired_female 
			
	drop beggars_male beggars_female inmates_male inmates_female 		
		
	* State/district ID:
	gen id_sd = state_code + district_code	

	save "$csv_1991/`dataset_name'_1991_nonworker.dta", replace


* Merging in to merge dataset
	use "$csv_1991/`dataset_name'_1991_merge.dta", clear
	drop _merge 

	merge m:1 id_sd rural using "$csv_1991/`dataset_name'_1991_nonworker.dta"

	foreach varnw in total_non_workers male_non_workers female_non_workers household_nonworker_male household_nonworker_female students_nonworker_female students_nonworker_male dependents_male dependents_female retired_male retired_female non_worker_discount {
	replace `varnw' = . if (education_level != 10)
}

	drop _merge 
	
	save "$csv_1991/`dataset_name'_1991_merge.dta", replace	
	
end 	

* Applying program to all states 
local states "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar_haveli daman_diu delhi lakshadweep pondicherry"

* Applying program to each state
foreach state in `states' {
	non_worker_data "`state'"
	}


********************************************************************************

// ADDING FERTILITY AND AGE AT MARRIAGE DATA 1991

clear all

capture program drop process_marriagef_1991

program define process_marriagef_1991

	args dataset_name // Capturing dataset name passed to the program
	display "Processing dataset: `dataset_name'"

		
	import delimited "$csv_1991/`dataset_name'_1991_marriagef.csv", clear
	save "$csv_1991/`dataset_name'_1991_marriagef.dta", replace	

	drop v1 v9 v10 v11 v12 v13 v14 // for now dropping births of order

	rename v2 state_code
	rename v3 district_code
	rename v4 district_name
	rename v5 rural
	rename v6 present_age
	rename v7 currently_married_women
	rename v8 births_last_year

	drop if missing(state_code)
	drop in 1/2	


	* Destringing variables	
	local vars_mdestring9 currently_married_women births_last_year
	foreach var in `vars_mdestring9' {
		replace `var' = trim(`var')
		replace `var' = subinstr(`var', ",", "", .)
		destring `var', replace force
	}
		

	* Encoding age	
	encode present_age, gen(present_age_num)
	drop present_age
	rename present_age_num present_age		
		
	* Want to drop separate women age observations where under 34, under 15
	keep if inlist(present_age, 1, 2, 3, 4, 9)

	save "$csv_1991/`dataset_name'_1991_marriagef.dta", replace	

	///

	* Need to add in women's population by age groups
	import delimited "$csv_1991/`dataset_name'_1991_womenage.csv", clear
	save "$csv_1991/`dataset_name'_1991_womenage.dta", replace	

	* Rename vars
	rename v2 state_code
	rename v3 district_code
	rename v4 district_name
	rename v5 rural
	rename v6 present_age
	rename v8 total_female_pop
	rename v10 rural_female_pop
	rename v12 urban_female_pop

	drop v1 v7 v9 v11 v13 // dropping unnecessary vars (male pop)
	drop if missing(state_code)
	drop in 1/2

	* Destringing vars
	local var_mdestring9_pop total_female_pop rural_female_pop urban_female_pop
	foreach var in `var_mdestring9_pop' {
		replace `var' = trim(`var')
		replace `var' = subinstr(`var', ",", "", .)
		destring `var', replace force
	}

	* Encoding age	
	encode present_age, gen(present_age_num)
	drop present_age
	rename present_age_num present_age	

	* Keeping to the same age groups - 15-34 years, and all ages
	keep if inlist(present_age, 4, 5, 6, 7, 23)

	* Relabelling age values so they match up to merge
	recode present_age (4 = 1) (5 = 2) (6 = 3) (7 = 4) (23 = 9)
	label define present_age_lbl 1 "15-19" 2 "20-24" 3 "25-29" 4 "30-34" 9 "All ages"
	label values present_age present_age_lbl


	* Reshaping to long format - to have 'Total', 'Rural', 'Urban' in rural var

	* Rename columns to fit reshape's expectations
	rename total_female_pop total_female_pop1
	rename rural_female_pop total_female_pop2
	rename urban_female_pop total_female_pop3

	* Reshape the data to long format
	reshape long total_female_pop, i(state_code district_code district_name present_age) j(rural_type)

	* Changing 'rural' name
	replace rural = "Total" if (rural_type == 1)
	replace rural = "Rural" if (rural_type == 2)
	replace rural = "Urban" if (rural_type == 3)

	* Drop unnecessary columns
	drop rural_type 

	rename total_female_pop female_pop

	tempfile women_pop_age
	save `women_pop_age', replace


	// Merging in 
	use "$csv_1991/`dataset_name'_1991_marriagef.dta"
	merge 1:1 state_code district_code rural present_age using `women_pop_age'

	drop _merge

	* If rural == 'Total', some values are missing so will drop these and add properly
	drop if missing(currently_married_women) & missing(births_last_year)

	save "$csv_1991/`dataset_name'_1991_marriagef.dta", replace

	* For 'rural' - don't have values for current_married_women or births_last_year - so sum rural and urban to give total for each district_area
	

	preserve 

	drop if rural == "Total"

	collapse (sum) currently_married_women births_last_year female_pop, by (state_code district_code district_name present_age)

	gen rural = "Total"

	tempfile total_counts_marriagef
	save `total_counts_marriagef', replace

	restore 


	///
	use "$csv_1991/`dataset_name'_1991_marriagef.dta"
	append using `total_counts_marriagef'


	* Reshape so fifteen new vars with age going across - to merge into the master dataset
	reshape wide currently_married_women births_last_year female_pop, i(state_code district_code district_name rural) j(present_age)

	* Rename and relabel so more informative and can track age groups
	rename currently_married_women1 married_women1519
	label var married_women1519 "Currently married women between 15 - 19 years old"
	rename births_last_year1 births_last_year1519
	label var births_last_year1519 "Number of births in the past year from women 15 - 19 years old"
	rename female_pop1 female_pop1519

	rename currently_married_women2 married_women2024
	label var married_women2024 "Currently married women aged 20 - 24 years old"
	rename births_last_year2 births_last_year2024
	rename female_pop2 female_pop2024

	rename currently_married_women3 married_women2529 
	label var married_women2529 "Currently married women aged 25 - 29 years old"
	rename births_last_year3 births_last_year2529
	rename female_pop3 female_pop2529

	rename currently_married_women4 married_women3034
	label var married_women3034 "Currently married women aged 30 - 34 years old"
	rename births_last_year4 births_last_year3034
	rename female_pop4 female_pop3034

	rename currently_married_women9 married_womenall
	label var married_womenall "Number of married women across all ages"
	rename births_last_year9 births_last_yearall
	rename female_pop9 female_popall

	save "$csv_1991/`dataset_name'_1991_marriagef.dta", replace

end program

local states "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar_haveli daman_diu delhi lakshadweep pondicherry"

* Applying program to each state
foreach state in `states' {
	process_marriagef_1991 "`state'"
	}

// Appending all these together	
clear 
cd "$csv_1991"

use "andhra_pradesh_1991_marriagef.dta", clear


local statesa "arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar_haveli daman_diu delhi lakshadweep pondicherry"


foreach state in `statesa' {
	append using "`state'_1991_marriagef.dta"
}

save "$csv_1991/appended_marriage1991.dta", replace	

	
********************************************************************************	
********************************************************************************

// APPENDING 1991 DATASETS TOGETHER

* Appending 1991

clear 
cd "$csv_1991"

local states_1 "arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar_haveli daman_diu delhi lakshadweep pondicherry"

use "andhra_pradesh_1991_merge", clear

foreach state in `states_1' {
	append using "`state'_1991_merge"
}


* Merging in fertility and marriage data here 
merge m:1 state_code district_code rural using "$csv_1991/appended_marriage1991.dta"


* Delhi in 1991 is only one district; duplicate observations of State: Delhi, District: Delhi - so dropping the second
drop if id_sd == "3101"

* Same with Chandigarh, Dadra and Nagar Haveli, and Lakshadweep 
drop if id_sd == "2801"
drop if id_sd == "2901"
drop if id_sd == "3201"

* Renaming duplicate districts across different states (Aurangabad, Hamirpur, Raigarh)
replace district_name = "district-aurangabadbihar" if (id_sd == "0505")
replace district_name = "district-aurangabadmaha" if (id_sd == "1415")
replace district_name = "district-hamirpurup" if (id_sd == "2541")
replace district_name = "district-hamirpurhp" if (id_sd == "0903")
replace district_name = "district-raigarhmp" if (id_sd == "1341")
replace district_name = "district-raigarhmaha" if (id_sd == "1403") 


* Merging education groups so same categories as 2001 - condensing
gen education_category = 0 //
* Will collapse(sum) by new education category
	replace education_category = 1 if (education_level == 1)
	replace education_category = 2 if inlist(education_level, 2, 3, 4)
	replace education_category = 3 if inlist(education_level, 5, 6, 7, 8) // including technical diploma because full catgeory name is technical diploma or certificate not equal to degree
	replace education_category = 4 if (education_level == 9) 
	replace education_category = 5 if (education_level == 10)

* Relabelling education
label define education_category_lbl 1 "Illiterate" 2 "Literate but below matric/secondary" 3 "Matric/secondary but below graduate" 4 "Graduate and above" 5 "Total"
label values education_category education_category_lbl

* Collapsing to sum the combined education
collapse (sum) *_total *_female *_male total_pop *_total2 *_male2 *_female2 married_women1519 married_women2024 married_women2529 married_women3034  married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount, by(state_code district_code id_sd district_name rural education_category)


********************************************************************************
********************************************************************************
// Merging for consistency of composite regions - here doing after appending states together (as opposed to 2001 construction of composite regions which was done before appending states together), so here will use id_sd as identifier
 

/* Using a conditional statement: if id_sd is either ... or ..., the merged_district code value takes on '08', otherwise it takes on the original district code. 
i.e. ... = cond(statement, if true then this, else this) */


// Assam
* Merge Dhubri and Kokorajhar --> Dhubri and Kokrajhar

* Condition so merged_district takes the value "0401" for Dhubri or Kokorajhar, otherwise is the id_sd value
gen merged_district = cond(id_sd == "0401" | id_sd == "0402", "0401", id_sd)
replace district_name = "District - Dhubri and Kokrajhar" if (id_sd == "0401" | id_sd == "0402")
replace id_sd = "0401" if (id_sd == "0402") // both districts have same id_sd
replace district_code = "01" if (id_sd == "0401") // so that both districts have the same district_code to collapse 


// Bihar
* Merging Munger and Nalanda
replace merged_district = cond(id_sd == "0526" | id_sd == "0502", "0502", id_sd)
replace district_name = "District - Munger and Nalanda" if (id_sd == "0526" | id_sd == "0502")
replace id_sd = "0502" if (id_sd == "0526")
replace district_code = "02" if (id_sd == "0502")

* Merging Dhanbad and Giridih
replace merged_district = cond(id_sd == "0532" | id_sd == "0533", "0532", id_sd)
replace district_name = "District - Dhanbad and Giridih" if (id_sd == "0532" | id_sd == "0533")
replace id_sd = "0532" if (id_sd == "0533")
replace district_code = "32" if (id_sd == "0532") 


// Gujarat
* Merge Banas Kantha, Kheda, Mahesena, Gandhinagar and Ahmadabad
gen comp_gujarat = 0 //
	replace comp_gujarat = 1 if inlist(id_sd, "0708", "0713", "0710", "0711", "0712")
	
replace merged_district = "0708" if (comp_gujarat == 1)	
replace district_name = "Gujarat composite region" if (comp_gujarat == 1)
replace district_code = "08" if (comp_gujarat == 1)
replace id_sd = "0708" if (comp_gujarat == 1)

drop comp_gujarat

* Merge Junagadh, Bhavnagar, Amreli 
replace merged_district = cond(id_sd == "0706" | id_sd == "0704" | id_sd == "0705", "0704", id_sd)
replace district_name = "Junagadh, Bhavnagar, Amreli" if (id_sd == "0704" | id_sd == "0705" | id_sd == "0706")
replace id_sd = "0704" if (id_sd == "0706" | id_sd == "0705")
replace district_code = "04" if (id_sd == "0704") 

* Merge Vadodara and Bharuch
replace merged_district = cond(id_sd == "0715" | id_sd == "0716", "0715", id_sd)
replace district_name = "District - Vadodara and Bharuch" if (id_sd == "0715" | id_sd == "0716")
replace district_code = "15" if (id_sd == "0716")
replace id_sd = "0715" if (id_sd == "0716")


// Haryana
* Composite region
gen haryana_comp = 0 //
	replace haryana_comp = 1 if inlist(id_sd, "0813", "0815", "0814", "0804", "0805", "0803", "0806")
	replace haryana_comp = 1 if inlist(id_sd, "0811", "0808", "0807", "0802")
replace merged_district = "0802" if (haryana_comp == 1)
replace district_name = "Haryana composite region" if (haryana_comp == 1)
replace id_sd = "0802" if (haryana_comp == 1)
replace district_code = "02" if (haryana_comp == 1) 	

drop haryana_comp


// Karnataka

* Bellary, Shimoga, Chitradurga
replace merged_district = "1104" if inlist(id_sd, "1104", "1118", "1108")
replace district_name = "Bellary, Shimoga, Chitradurga" if inlist(id_sd, "1104", "1118", "1108")
replace id_sd = "1104" if inlist(id_sd, "1104", "1118", "1108")
replace district_code = "04" if inlist(id_sd, "1104", "1118", "1108")


// Kerala 
* Merge Ernakulam and Idukki
replace merged_district = "1208" if inlist(id_sd, "1208", "1209") // Don't need to have conditional statement anymore because already set other merged_district values - not restarting with a new dataset
replace district_name = "District - Ernakulam and Idukki" if inlist(id_sd, "1208", "1209") 
replace id_sd = "1208" if inlist(id_sd, "1208", "1209")
replace district_code = "08" if inlist(id_sd, "1208", "1209")


// Madhya Pradesh
* Bilaspur and Rajnandgaon
replace merged_district = "1340" if inlist(id_sd, "1340", "1342")
replace district_name = "District - Bilaspur and Rajnandgaon" if inlist(id_sd, "1340", "1342") 
replace id_sd = "1340" if inlist(id_sd, "1340", "1342")
replace district_code = "40" if inlist(id_sd, "1340", "1342")

* Gwalior and Datia
replace merged_district = "1303" if inlist(id_sd, "1303", "1304")
replace district_name = "District - Gwalior and Datia" if inlist(id_sd, "1303", "1304")
replace id_sd = "1303" if inlist(id_sd, "1303", "1304")
replace district_code = "03" if inlist(id_sd, "1303", "1304")


// Meghalaya 
* East and West Khasi Hills 
replace merged_district = "1602" if inlist(id_sd, "1602", "1603")
replace district_name = "District - East and West Khasi Hills" if inlist(id_sd, "1602", "1603")
replace id_sd = "1602" if inlist(id_sd, "1602", "1603")
replace district_code = "02" if inlist(id_sd, "1602", "1603")


// Punjab 
* Very large composite region - want to merge all districts in Punjab together except for Bathinda 
gen bathinda = 0 //
	replace bathinda = 1 if (id_sd == "2011")
gen punjab_composite = 0 //
	replace punjab_composite = 1 if ((state_code == "20") & (id_sd != "2011") & ((id_sd != "2000")))

replace merged_district = "2001" if (punjab_composite == 1)
replace district_name = "Punjab composite region" if (punjab_composite == 1)
replace id_sd = "2001" if (punjab_composite == 1)
replace district_code = "01" if (punjab_composite == 1)	

drop bathinda punjab_composite


// Tamil Nadu 	
* Ramanathapuram and Pasumpon Muthuramalinya (Pasumpon Thevar)
replace merged_district = "2315" if inlist(id_sd, "2318", "2315")
replace district_name = "District - Ramanathapuram and Pasumpon" if inlist(id_sd, "2318", "2315")
replace id_sd = "2315" if inlist(id_sd, "2315", "2318")
replace district_code = "15" if inlist(id_sd, "2315", "2318")


// Tripura
* North and South
replace merged_district = "2402" if inlist(id_sd, "2402", "2403")
replace district_name = "District - North and South Tripura" if inlist(id_sd, "2402", "2403")
replace id_sd = "2402" if inlist(id_sd, "2402", "2403")
replace district_code = "02" if inlist(id_sd, "2402", "2403")


// Uttar Pradesh
* Uttarakhand composite region	
gen up_composite = 0 //
	replace up_composite = 1 if inlist(id_sd, "2502", "2503", "2505", "2508", "2506")
replace merged_district = "2502" if	(up_composite == 1)
replace district_name = "Uttarakhand composite region" if inlist(id_sd, "2502", "2503", "2505", "2508", "2506")
replace id_sd = "2502" if (up_composite == 1)
replace district_code = "02" if (up_composite == 1)

* Ghaziabad and Bulandshahr
replace merged_district = "2516" if inlist(id_sd, "2516", "2517")
replace district_name = "District - Ghaziabad and Bulandshahr" if inlist(id_sd, "2516", "2517")
replace id_sd = "2516" if inlist(id_sd, "2516", "2517")
replace district_code = "16" if inlist(id_sd, "2516", "2517")

* Aligarh and Mathura 
replace merged_district = "2518" if inlist(id_sd, "2518", "2519")
replace district_name = "District - Aligarh and Mathura" if inlist(id_sd, "2518", "2519")
replace id_sd = "2518" if inlist(id_sd, "2518", "2519")
replace district_code = "18" if inlist(id_sd, "2518", "2519")

* Mainpuri and Etawah
replace merged_district = "2523" if inlist(id_sd, "2523", "2535")
replace district_name = "District - Mainpuri and Etawah" if inlist(id_sd, "2523", "2535")
replace id_sd = "2523" if inlist(id_sd, "2523", "2535")
replace district_code = "23" if inlist(id_sd, "2523", "2535")

* Rae Bareli, Sultanpur, Fatehpur
replace merged_district = "2533" if inlist(id_sd, "2533", "2550", "2543")
replace district_name = "District - Rae, Sultanpur, Fatehpur" if inlist(id_sd, "2533", "2550", "2543")
replace id_sd = "2533" if inlist(id_sd, "2533", "2550", "2543")
replace district_code = "33" if inlist(id_sd, "2533", "2550", "2543")

* Barabanki, Faizabad, Azamgarh
replace merged_district = "2548" if inlist(id_sd, "2548", "2549", "2557")
replace district_name = "Barabanki, Faizabad, Azamgarh" if inlist(id_sd, "2548", "2549", "2557")
replace id_sd = "2548" if inlist(id_sd, "2548", "2549", "2557")
replace district_code = "48" if inlist(id_sd, "2548", "2549", "2557")
	
* Siddharth Nagar and Basti
replace merged_district = "2551" if inlist(id_sd, "2551", "2553")
replace district_name = "District - Siddharth Nagar and Basti" if inlist(id_sd, "2551", "2553")
replace id_sd = "2551" if inlist(id_sd, "2551", "2553")
replace district_code = "51" if inlist(id_sd, "2551", "2553")

* Kanpur Dehat and Nagar
replace merged_district = "2536" if inlist(id_sd, "2536", "2537")
replace district_name = "District - Kanpur (Nagar and Dehat)" if inlist(id_sd, "2536", "2537")
replace id_sd = "2536" if inlist(id_sd, "2536", "2537")
replace district_code = "36" if inlist(id_sd, "2536", "2537")

	
// Collapsing
collapse (sum) *_total *_female *_male total_pop *_total2 *_male2 *_female2 married_women1519 married_women2024 married_women2529 married_women3034  married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount, by(state_code district_code id_sd district_name rural education_category)

********************************************************************************

// Need to construct shares now - using the main population total from merging the second dataset with disaggregated industry workers. Some discrepancies with main population count from first dataset, but correlation across all states essentially 1.


* Constructing employment rates - main workers (not considering marginal currently)
gen employment = main_pop_total2/total_pop
gen male_employment =  main_pop_male2/pop_male
gen female_employment = main_pop_female2/pop_female

* Now need to construct shares for the main worker industries with main worker count - using main worker population as sum of total shares
gen cultivator_share = cultivators_total/main_pop_total2
gen agriculture_share = agriculture_total/main_pop_total2
gen household_share = household_total/main_pop_total2
gen livestock_share = livestock_total/main_pop_total2
gen mining_share = mining_total/main_pop_total2
gen manu_industry_share = manu_industry_total/main_pop_total2
gen construction_share = construction_total/main_pop_total2
gen trade_share = trade_total/main_pop_total2
gen transport_share = transport_total/main_pop_total2
gen other_service_share = other_service_total/main_pop_total2

* Adding in 1991 dummy
gen year = 1
label define year_lbl 1 "1991" 2 "2001"
label values year year_lbl

* Cleaning up District names for matching later
replace district_name = trim(district_name)
replace district_name = lower(district_name)
replace district_name = subinstr(district_name, " ", "", .)

drop if (education_category == 0)

save "$working_data/all_1991.dta", replace

* Note: Census did not include Jammu and Kashmir in 1991 due to political unrest
	
	
********************************************************************************
   **************************************************************************
********************************************************************************


/// 2001 CLEANING //////////////////////////////////////////////////////////////

clear all
set more off, perm

* Initial cleaning for main dataset - will then import total population numers from a different dataset (to calculate employment)

* Defining programme
capture program drop process_2001
program define process_2001

    args dataset_name // Capturing dataset name passed to the program
    display "Processing dataset: `dataset_name'"

	import delimited "$csv_2001/`dataset_name'_2001_main.csv", clear
	save "$csv_2001/`dataset_name'_2001_main.dta", replace

	drop v1 v4
	rename v2 state_code
	rename v3 district_code
	rename v5 district_name
	rename v6 rural
	rename v7 education_level
	rename v8 main_pop_total
	rename v9 main_pop_male
	rename v10 main_pop_female

	* Merging industry categories together to be uniform with 1991
	rename v11 cultivators_total
	rename v12 cultivators_male
	rename v13 cultivators_female
	rename v14 agriculture_total 
	rename v15 agriculture_male
	rename v16 agriculture_female
	rename v17 livestock_total
	rename v18 livestock_male
	rename v19 livestock_female
	rename v20 mining_total
	rename v21 mining_male
	rename v22 mining_female
	rename v23 household_total
	rename v24 household_male
	rename v25 household_female 
	rename v26 manu_industry_total
	rename v27 manu_industry_male
	rename v28 manu_industry_female

	rename v32 construction_total
	rename v33 construction_male
	rename v34 construction_female
	rename v35 trade_total
	rename v36 trade_male
	rename v37 trade_female
	rename v41 transport_total
	rename v42 transport_male
	rename v43 transport_female

	rename v47 other_service_total
	rename v48 other_service_male
	rename v49 other_service_female

	* Destringing variables:
	local vars_to_destring2001 main_pop_total main_pop_male main_pop_female cultivators_total cultivators_male cultivators_female agriculture_total agriculture_male agriculture_female livestock_total livestock_male livestock_female mining_total mining_male mining_female household_total household_male household_female manu_industry_total manu_industry_male manu_industry_female construction_total construction_male construction_female trade_total trade_male trade_female transport_total transport_male transport_female other_service_total other_service_male other_service_female v29 v30 v31 v38 v39 v40 v44 v45 v46

	foreach var in `vars_to_destring2001' {
		replace `var' = trim(`var')
		replace `var' = subinstr(`var', ",", "", .)
		replace `var' = regexr(`var', "[^0-9.-]", "")
		destring `var', replace force
		}	
	* In the loop, adding some extra conditions to take care of any spaces, commas etc. and only keep the numerical values

	* Reassigning the remaining industry variables:
	* Assigning electricity, gas and water supply to mining and quarrying 
	replace mining_total = mining_total + v29
	replace mining_male = mining_male + v30
	replace mining_female = mining_female + v31
	drop v29 v30 v31

	* Assigning hotels and restaurants to wholesale and retail trade:
	replace trade_total = trade_total + v38
	replace trade_male = trade_male + v39
	replace trade_female = trade_female + v40
	drop v38 v39 v40

	* Assigning financial intermediation and real estate, renting and business activities to other services
	replace other_service_total = other_service_total + v44
	replace other_service_male = other_service_male + v45
	replace other_service_female = other_service_female + v46
	drop v44 v45 v46
		
	* Generating a state_district id variable
	gen id_sd = state_code + district_code

	* Sorting random headings/table gaps
	drop if (missing(state_code) & missing(district_code))
	drop if _n <= 3

	* Encoding education level to be a numeric label-value variable
	encode education_level, gen(education_level_num)
	drop education_level
	rename education_level_num education_level

	* (Note: education categories do not match with 1991 - here 7 education categories, 1991 data has 9 categories)
		
	* Resaving	
	save "$csv_2001/`dataset_name'_2001_main.dta", replace
	
end

* Applying to all states
 
	local states_2001 "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar daman_diu delhi lakshadweep pondicherry uttarakhand chhattisgarh jharkhand"

	* Applying program to each state
	foreach state in `states_2001' {
		process_2001 "`state'"
	} 
	
********************************************************************************

// IMPORTING TOTAL POPULATION 2001 - not in employment prior dataset
clear all

* Defining programme
capture program drop pop_2001
program define pop_2001

    args dataset_name // Capturing dataset name passed to the program
    display "Processing dataset: `dataset_name'"

	import delimited "$csv_2001/`dataset_name'_pop2001.csv", clear
	save "$csv_2001/`dataset_name'_pop2001.dta", replace

	drop v1 v4
	rename v2 state_code
	rename v3 district_code
	rename v5 district_name
	rename v6 rural
	rename v7 education_level
	rename v8 total_pop
	rename v9 pop_male
	rename v10 pop_female
	rename v20 total_non_worker
	rename v21 non_worker_male
	rename v22 non_worker_female
	rename v23 total_seeking_work
	rename v24 seeking_work_male
	rename v25 seeking_work_female

	drop if (missing(state_code) & missing(district_code))
	drop if _n <= 3

	* Destringing vars
	local destring_var total_pop pop_male pop_female total_non_worker non_worker_female non_worker_male total_seeking_work seeking_work_male seeking_work_female
	foreach var in `destring_var' {
			destring `var', gen (`var'_des)
		drop `var'
		rename `var'_des `var'
		}
		
	* Encoding education - sorting out education?
	encode education_level, gen(education_level_num)
	drop education_level
	rename education_level_num education_level
		
	* Dropping irrelevant variables	that will not use for analysis (non_workers/those seeking work are not in 1991 dataset so dropping to keep uniformity)
	drop v11 v12 v13 v14 v15 v16 v17 v18 v19 total_non_worker non_worker_female non_worker_male total_seeking_work seeking_work_male seeking_work_female 	
		
	* Remember - within the program, tempfile does not need to have a unique name by state	
	tempfile 2001pop_temp
	save `2001pop_temp', replace

	* Merging to include total population vars in main dataset
	use "$csv_2001/`dataset_name'_2001_main.dta", clear
	merge 1:1 state_code district_code rural education_level using `2001pop_temp'

	save "$csv_2001/`dataset_name'_2001_merge.dta", replace

end

* Applying to all states
 
	local states_2001 "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar daman_diu delhi lakshadweep pondicherry uttarakhand chhattisgarh jharkhand"

	* Applying program to each state
	foreach state in `states_2001' {
		pop_2001 "`state'"
	} 

	
********************************************************************************

// ADDING IN NON-WORKER DATA 2001 (to discount employment measure)

clear all

capture program drop nonworkers_2001
program define nonworkers_2001

    args dataset_name
    display "Processing dataset: `dataset_name'"

	import delimited "$csv_2001/`dataset_name'_2001_nonworker.csv", clear
	save "$csv_2001/`dataset_name'_2001_nonworker.dta", replace

	drop v1 v13 v10 v16 v19 v22 v23 v24 v25 v26 v27 v28

	rename v2 state_code
	rename v3 district_code
	rename v4 district_name
	rename v5 rural
	rename v6 age_group 
	rename v7 total_non_workers
	rename v8 male_non_workers
	rename v9 female_non_workers
	rename v11 students_nonworker_male
	rename v12 students_nonworker_female
	rename v14 household_nonworker_male
	rename v15 household_nonworker_female
	rename v17 dependents_male
	rename v18 dependents_female
	rename v20 retired_male
	rename v21 retired_female 


	drop if missing(state_code) & missing(district_code)

	drop if _n == 1

	* Only keeping totals, not disaggregated by age
	keep if (age_group == " Total")
	drop age_group 

	* Destringing vars 
	local vars_destring_nw total_non_workers male_non_workers female_non_workers household_nonworker_male household_nonworker_female students_nonworker_male students_nonworker_female dependents_male dependents_female retired_male retired_female 

	* Destring the selected variables 
	foreach var in `vars_destring_nw' {
		replace `var' = trim(`var')
		replace `var' = subinstr(`var', "**", "", .)
		destring `var', replace force
		}	

	* Generating sums of populations to discount, then dropping - dependents and pensioners only
	gen non_worker_discount = dependents_male + dependents_female + retired_male + retired_female 
	label var non_worker_discount "Sum of non-workers classified as dependents and pensioners"		
		
	* State/district ID:
	replace district_code = "0" + district_code if strlen(district_code) == 1
	replace state_code = "0" + state_code if strlen(state_code) == 1
	gen id_sd = state_code + district_code	

	save "$csv_2001/`dataset_name'_2001_nonworker.dta", replace


* Merging in to merge dataset
	use "$csv_2001/`dataset_name'_2001_merge.dta", clear
	drop _merge 

	merge m:1 state_code district_code rural id_sd using "$csv_2001/`dataset_name'_2001_nonworker.dta"

	foreach varnw in total_non_workers male_non_workers female_non_workers household_nonworker_male household_nonworker_female students_nonworker_female students_nonworker_male dependents_male dependents_female retired_male retired_female non_worker_discount {
	replace `varnw' = . if (education_level != 8)
}
	
	save "$csv_2001/`dataset_name'_2001_merge.dta", replace	

end program


* Applying to all states
local states_2001 "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar daman_diu delhi lakshadweep pondicherry uttarakhand chhattisgarh jharkhand"

* Applying program to each state
foreach state in `states_2001' {
	 nonworkers_2001 "`state'"
	} 

		
********************************************************************************

// ADDING FERTILITY AND AGE AT MARRIAGE DATA 2001


clear all

capture program drop process_marriagef_2001
program define process_marriagef_2001     
	
	args dataset_name // Capturing dataset name passed to the program
    display "Processing dataset: `dataset_name'"

	import delimited "$csv_2001/`dataset_name'_2001_marriagef.csv", clear
	save "$csv_2001/`dataset_name'_2001_marriagef.dta", replace
	
	drop v1 v11 v12 v13 v14 v15 v16 v17 v18 v19 v20 // dropping the order of births data
	
	* Renaming vars
	rename v2 state_code
	rename v3 district_code
	rename v4 district_name
	rename v5 rural
	rename v6 present_age
	rename v7 female_pop
	rename v8 currently_married_women
	rename v9 mbirths_last_year
	rename v10 fbirths_last_year
	
	* Destringing variables	
	local var_mdestring1 female_pop currently_married_women mbirths_last_year fbirths_last_year 
	foreach var in `var_mdestring1' {
		replace `var' = trim(`var')
		replace `var' = subinstr(`var', ",", "", .)
		destring `var', replace force
		}

	drop if missing(state_code) & missing(district_code)

	drop in 1/2	

	* Encoding age	
	encode present_age, gen(present_age_num)
	drop present_age
	rename present_age_num present_age		
		
	* Want to drop separate women age observations where older than 34, under 15
	keep if inlist(present_age, 1, 2, 3, 4, 9)

	label define present_age_lbl 1 "15-19" 2 "20-24" 3 "25-29" 4 "30-34" 9 "All ages"
	label values present_age present_age_lbl
		
	* Generating total number of births in last year (1991 doesn't split by gender)
	gen births_last_year = mbirths_last_year + fbirths_last_year
	drop mbirths_last_year fbirths_last_year

	* Reshaping data - so have fifteen columns - 3 for each age classification
	reshape wide currently_married_women births_last_year female_pop, i(state_code district_code district_name rural) j(present_age)

	* Rename and relabel so more informative and can track age groups
	rename currently_married_women1 married_women1519
	label var married_women1519 "Currently married women between 15 - 19 years old"
	rename births_last_year1 births_last_year1519
	label var births_last_year1519 "Number of births in the past year from women 15 - 19 years old"
	rename female_pop1 female_pop1519

	rename currently_married_women2 married_women2024
	label var married_women2024 "Currently married women aged 20 - 24 years old"
	rename births_last_year2 births_last_year2024
	rename female_pop2 female_pop2024

	rename currently_married_women3 married_women2529 
	label var married_women2529 "Currently married women aged 25 - 29 years old"
	rename births_last_year3 births_last_year2529
	rename female_pop3 female_pop2529

	rename currently_married_women4 married_women3034
	label var married_women3034 "Currently married women aged 30 - 34 years old"
	rename births_last_year4 births_last_year3034
	rename female_pop4 female_pop3034

	rename currently_married_women9 married_womenall
	label var married_womenall "Number of married women across all ages"
	rename births_last_year9 births_last_yearall
	rename female_pop9 female_popall

	save "$csv_2001/`dataset_name'_2001_marriagef.dta", replace	
	
end program 
	
* Applying to all states
 
local states_2001 "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar daman_diu delhi lakshadweep pondicherry uttarakhand chhattisgarh jharkhand"

	* Applying program to each state
	foreach state in `states_2001' {
		process_marriagef_2001 "`state'"
	} 


* Now we want to merge this marriage and fertility data into the _merge	district. Do this now so that the composite regions are fixed.

local states_2001 "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar daman_diu delhi lakshadweep pondicherry uttarakhand chhattisgarh jharkhand"

foreach state in `states_2001' {
	use "$csv_2001/`state'_2001_merge.dta", clear
	capture drop _merge
	
	merge m:1 state_code district_code rural using "$csv_2001/`state'_2001_marriagef.dta"
	capture drop _merge

	save "$csv_2001/`state'_2001_merge.dta", replace
}



********************************************************************************

// Adding migration data as a control
			
* To control for the possibility of migration between 1991 and 2001 potentially dampening regional labour market effects, add controls for the shares of people migrating both inter-state and intra-state 

* These controls are at the level of state - i.e. every district in the same state has these same values - so we are merging onto the full dataset - will only need to sort out Jharkhand, Uttarakhand and ... separations .

			
clear all			
			
capture program drop migration_control

program define migration_control 
    args dataset_name // Capturing dataset name passed to the program
    display "Processing dataset: `dataset_name'"

	import delimited "$csv_2001/`dataset_name'_2001_migration.csv", clear

	drop v1

	drop v15 v16 v17 v18 v19 v20 v24 v25 v26 v27
	drop v28 v29 v30 v31 v32

	rename v2 state_code
	rename v3 district_code
	rename v4 state_name
	rename v5 rural
	rename v7 last_residence
	rename v6 duration_last_residence
	rename v8 rural_last_residence
	rename v9 total_migrants
	rename v10 total_migrants_male 
	rename v11 total_migrants_female 
	rename v12 migr_employment_total
	rename v13 migr_employment_male
	rename v14 migr_employment_female 
	 
	rename v21 migr_marriage_total
	rename v22 migr_marriage_male
	rename v23 migr_marriage_female

	keep if (rural_last_residence == "Total")
	keep if (rural == "Urban") // Only want to keep migration data to urban areas within, not focussed on whether migrants' last residence was urban/rural 
	keep if inlist(last_residence, "In other districts of the state of enumeration", "States in India beyond the state of enumeration")
	 
	drop if inlist(duration_last_residence, "All durations of residence", "Duration of residence 10 years and above") 
	
	local var_migrdestring total_migrants total_migrants_male total_migrants_female migr_employment_total migr_employment_male migr_employment_female migr_marriage_total migr_marriage_male migr_marriage_female
	foreach var in `var_migrdestring' {
		replace `var' = trim(`var')
		replace `var' = subinstr(`var', ",", "", .)
		destring `var', replace force
		}
	 
	* Summing for migrants who have lived in place for under 10 years
	collapse (sum) total_migrants total_migrants_male total_migrants_female migr_employment_total migr_employment_male migr_employment_female migr_marriage_total migr_marriage_male migr_marriage_female, by(state_code district_code state_name rural last_residence)
	
	encode last_residence, gen(last_residence_num)
	drop last_residence
	rename last_residence_num last_residence	

	recode last_residence (1 = 2) (2 = 4)

	* Reshaping so for each migration type, reason is another column 

	* 2 - inter-state (another district), 4 - intra-state (another state) 

	reshape wide total_migrants total_migrants_male total_migrants_female migr_employment_total migr_employment_male migr_employment_female migr_marriage_total migr_marriage_male migr_marriage_female, i(state_code district_code state_name rural) j(last_residence)

	label var total_migrants2 "Total migrants from another district within state"
	label var total_migrants4 "Total migrants from another state"

	save "$csv_2001/`dataset_name'_2001_migration.dta", replace
			
end program 
			
						
local states_2001 "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar daman_diu delhi lakshadweep pondicherry uttarakhand chhattisgarh jharkhand"

* Applying program to each state
foreach state in `states_2001' {
	migration_control "`state'"
} 


* We now want to merge so that each district within the state has the same values (state-level controls)
local states_2001 "andhra_pradesh arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar daman_diu delhi lakshadweep pondicherry uttarakhand chhattisgarh jharkhand"

foreach state in `states_2001' {
	use "$csv_2001/`state'_2001_merge.dta", clear
	capture drop _merge
	
	merge m:1 state_code rural district_code using "$csv_2001/`state'_2001_migration.dta"
	capture drop _merge

	save "$csv_2001/`state'_2001_merge.dta", replace
}
	

********************************************************************************
********************************************************************************

// Constructing 2001 composite regions (to have unchanged district boundaries )

/* New states have formed, districts have partitioned, some villages/tehsils moved from one district to another. 

Construct composite regions

For now we aren't worrying about district codes - will match to the 1991 ones and have removed district codes from the district name
*/

* Want to avoid any mistakes/mess-ups by changing now: but merging many composite regions together could have been much cleaner/simpler instead of listing all the district codes, use condition of merged_district code. 


**********
// Arunachal Pradesh: Merging East and Upper Siang into East Siang, and merging Lower Subanisiri and Papum Pare into Lower Subanisiri 

use "$csv_2001/arunachal_pradesh_2001_merge.dta", clear

/* Using a conditional statement: if the district_code is either (East Siang or Upper Siang, the merged_district code value takes on '08', otherwise it takes on the original district code. 
i.e. ... = cond(statement, if true then this, else this)

* Same for Papum Pare (04) and Lower Subanisiri (05)*/

gen merged_district = cond(district_code == "08" | district_code == "09", "08", district_code)
replace merged_district = cond(district_code == "04" | district_code == "05", "04", merged_district)

* Renaming district
replace district_name = "District - East Siang  08" if (district_code == "09")
replace district_code = "08" if (district_code == "09")
replace id_sd = "1208" if (id_sd == "1209")

replace district_name = "District - Lower Subansiri 05" if (district_code == "04")
replace district_code = "04" if (district_code == "05")
* Standardising the district name 
replace district_name = "District - Lower Subansiri 05" if district_code == "04"
replace id_sd = "1204" if (id_sd == "1205")
 
* Collapse (sum) while keeping the splits by rural and education level
collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)


* Saving modified
save "$csv_2001/arunachal_pradesh_2001_merge.dta", replace

**********
// Assam: Merge Dhubri and Kokrajhar
use "$csv_2001/assam_2001_merge.dta", clear

gen merged_district = cond(district_code == "01" | district_code == "02", "01", district_code)

replace district_name = "District - Dhubri and Kokrajhar" if (district_code == "01" | district_code == "02")
replace district_code = "01" if (district_code == "02")
replace id_sd = "1801" if (id_sd == "1802")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)


save "$csv_2001/assam_2001_merge.dta", replace


********************************************************************************
// Bihar: Patna is unchanged. Bit complicated, 13 districts created a new state, many districts split as a separate state - Jharkhand

* First appending Jharkhand to Bihar to then reorganise after
use "$csv_2001/bihar_2001_merge.dta", clear
append using "$csv_2001/jharkhand_2001_merge.dta"


drop id_sd	

* Sorting out Jharkhand district codes to be able to collapse properly
gen district_code_numeric = real(district_code) // converting district code to numeric
replace district_code_numeric = district_code_numeric + 38  if (state_code == "20")
replace district_code = string(district_code_numeric, "%02.0f") if (state_code == "20")
drop district_code_numeric

* Changing Jharkhand state code to Bihar's
replace state_code = "10" if (state_code == "20")
gen id_sd = state_code + district_code

* Merging Sitamarhi and Sheohar --> Sitamarhi
gen merged_district = cond(district_code == "03" | district_code == "04", "03", district_code)
replace district_name = "District - Sitamarhi" if (district_code == "03" | district_code == "04")
replace district_code = "03" if (district_code == "04")
replace id_sd = "1003" if (id_sd == "1004") 

* Merging Saharsa and Supaul --> Saharsa
replace merged_district = cond(district_code == "12" | district_code == "06", "06", district_code)
replace district_name = "District - Saharsa" if (district_code == "06" | district_code == "12")
replace district_code = "06" if (district_code == "12")
replace id_sd = "1006" if (id_sd == "1012") 

* Merging Bhagalpur and Banka --> Bhagalpur
replace merged_district = cond(district_code == "22" | district_code == "23", "22", district_code)
replace district_name = "District - Bhagalpur" if (district_code == "22" | district_code == "23")
replace district_code = "22" if (district_code == "23")
replace id_sd = "1022" if (id_sd == "1023") 

* Merging Munger, Sheikphura, Nalanda, Lakhisarai, Jamui --> Munger and Nalanda
replace merged_district = cond(district_code == "24" | district_code == "25" | district_code == "26" | district_code == "27" | district_code == "37", "24", district_code)
replace district_name = "District - Munger and Nalanda" if (district_code == "24" | district_code == "25" | district_code == "26" | district_code == "27" | district_code == "37")
replace district_code = "24" if (district_code == "25" | district_code == "26" | district_code == "27" | district_code == "37")
replace id_sd = "1024" if (id_sd == "1025" | id_sd == "1026" | id_sd == "1027" | id_sd == "1037") 

* Merging Bhojpur and Buxar --> Bhojpur
replace merged_district = cond(district_code == "29" | district_code == "30", "29", district_code)
replace district_name = "District - Bhojpur" if (district_code == "29" | district_code == "30")
replace district_code = "29" if (district_code == "30")
replace id_sd = "1029" if (id_sd == "1030") 

* Merging Rohtas and Kaimur --> Rohtas
replace merged_district = cond(district_code == "31" | district_code == "32", "31", district_code)
replace district_name = "District - Rohtas" if (district_code == "31" | district_code == "32")
replace district_code = "31" if (district_code == "32")
replace id_sd = "1031" if (id_sd == "1032") 

// Sorting out districts transferred to Jharkhand state

* Merging Palamu and Garhwa --> Palamu
replace merged_district = cond(district_code == "39" | district_code == "40", "39", district_code)
replace district_name = "District - Palamu" if (district_code == "39" | district_code == "40")
replace district_code = "39" if (district_code == "40")
replace id_sd = "1039" if (id_sd == "1040")

* Merge Chatra, Hazaribagh and Kodarma --> Hazaribagh
replace merged_district = cond(district_code == "41" | district_code == "42" | district_code == "43", "41", district_code)
replace district_name = "District - Hazaribag" if (district_code == "41" | district_code == "42" | district_code == "43")
replace district_code = "41" if (district_code == "42" | district_code == "43")
replace id_sd = "1041" if (id_sd == "1042" | id_sd == "1043")

* Merge Pakaur and Sahibganj --> Sahibganj
replace merged_district = cond(district_code == "48" | district_code == "47", "47", district_code)
replace district_name = "District - Sahibganj" if (district_code == "47" | district_code == "48")
replace district_code = "47" if (district_code == "48")
replace id_sd = "1047" if (id_sd == "1048")

* Merge Bokaro, Dhanbad and Giridih --> Dhanbad and Giridih
replace merged_district = cond(district_code == "50" | district_code == "51" | district_code == "44", "44", district_code)
replace district_name = "District - Dhanbad and Giridih" if (district_code == "44" | district_code == "50" | district_code == "51")
replace district_code = "44" if (district_code == "50" | district_code == "51")
replace id_sd = "1044" if (id_sd == "1050" | id_sd == "1051")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

* Careful, you can't run this separately multiple times or will keep appending Jharkhand
save "$csv_2001/bihar_2001_merge.dta", replace


**********
// Daman and Diu 
use "$csv_2001/daman_diu_2001_merge.dta", clear

keep if (district_code == "00")

save "$csv_2001/daman_diu_2001_merge.dta", replace

********************************************************************************
// Gujarat
use "$csv_2001/gujarat_2001_merge.dta", clear

* Merging Banas Kantha, Patan, Kheda, Mahasenna, Gandhinagar, Ahmdabad, Anand
gen merged_district = cond(district_code == "02" | district_code == "03" | district_code == "04" | district_code == "16" | district_code == "06" | district_code == "15" | district_code == "07", "02", district_code) //
replace district_name = "Gujarat composite region" if (district_code == "02" | district_code == "03" | district_code == "04" | district_code == "16" | district_code == "06" | district_code == "07" | district_code == "15") //
replace district_code = "02" if (district_code == "03" | district_code == "04" | district_code == "06" | district_code == "07" | district_code == "16" | district_code == "15") //
replace id_sd = "2402" if (id_sd == "2403" | id_sd == "2404" | id_sd == "2406" | id_sd == "2407" | id_sd == "2416" | id_sd == "2415")

* Merge Junagadh, Porbandar, Bhavnagar, Amreli --> J, B, A
replace merged_district = cond(district_code == "12" | district_code == "11" | district_code == "14" | district_code == "13", "11", district_code) //
replace district_name = "Junagadh, Bhavnagar, Amreli" if (district_code == "12" | district_code == "11" | district_code == "14" | district_code == "13", "11", district_code) //
replace district_code = "11" if (district_code == "12" | district_code == "13" | district_code == "14") //
replace id_sd = "2411" if (id_sd == "2412" | id_sd == "2413" | id_sd == "2414")

* Merge Panch Mahals and Dohad --> Panch Mahals
replace merged_district = cond(district_code == "17" | district_code == "18", "17", district_code) //
replace district_name = "District - Panch Mahals" if (district_code == "17" | district_code == "18") //
replace district_code = "17" if (district_code == "18") //
replace id_sd = "2417" if (id_sd == "2418") 

* Merge Vadodara, Bharuch, Narmada --> V & B
replace merged_district = cond(district_code == "19" | district_code == "20" | district_code == "21", "19", district_code) //
replace district_name = "District - Vadodara and Bharuch" if (district_code == "19" | district_code == "20" | district_code == "21") //
replace district_code = "19" if (district_code == "20" | district_code == "21") //
replace id_sd = "2419" if (id_sd == "2420" | id_sd == "2421") 

* Merge Valsad and Narsari --> Valsad 
replace merged_district = cond(district_code == "25" | district_code == "24", "24", district_code)
replace district_name = "District - Valsad" if (district_code == "24" | district_code == "25")
replace district_code = "24" if (district_code == "25")
replace id_sd = "2424" if (id_sd == "2425") 

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/gujarat_2001_merge.dta", replace


**********
// Haryana
use "$csv_2001/haryana_2001_merge.dta", clear

* Merging Ambala and Panchkula --> Ambala
gen merged_district = cond(district_code == "01" | district_code == "02", "01", district_code)
replace district_name = "District - Ambala" if (district_code == "01" | district_code == "02")
replace district_code = "01" if (district_code == "02")
replace id_sd = "0601" if (id_sd == "0602") 

* Creating Haryana composite region
replace merged_district = cond(district_code == "03" | district_code == "04" | district_code == "05" | district_code == "06" | district_code == "07" | district_code == "08" | district_code == "09" | district_code == "10" | district_code == "12" | district_code == "13" | district_code == "14" | district_code == "15" | district_code == "17", "03", district_code)
replace district_name = "Haryana composite region" if (merged_district == "03")
replace district_code = "03" if (merged_district == "03")
replace id_sd = "0603" if (merged_district == "03")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/haryana_2001_merge.dta", replace


********************************************************************************
// Madhya Pradesh: 

* Append Chhattisgarh
use "$csv_2001/madhya_pradesh_2001_merge.dta", clear

append using "$csv_2001/chhattisgarh_2001_merge.dta"

drop id_sd

* Sorting out Chhattisgarh district and state codes - don't want to start from 0 again and have district_code duplicates
gen district_code_numeric = real(district_code) // conerting district code to numeric
replace district_code_numeric = district_code_numeric + 46  if (state_code == "22")
replace district_code = string(district_code_numeric, "%02.0f") if (state_code == "22")
drop district_code_numeric

* Changing Chhattisgarh state code to Madhya Pradesh's
replace state_code = "23" if (state_code == "22")
gen id_sd = state_code + district_code

// Chhattisgarh districts

* Merging Surguja and Koriya --> Surguja
gen merged_district = cond(district_code == "47" | district_code == "48", "47", district_code)
replace district_name = "District - Surguja" if (district_code == "47" | district_code == "48")
replace district_code = "47" if (district_code == "48")
replace id_sd = "2347" if (id_sd == "2348") 

* Merging Raigarh and Jaspur --> Raigarh
replace merged_district = cond(district_code == "49" | district_code == "50", "49", district_code)
replace district_name = "District - Raigarh" if (district_code == "49" | district_code == "50")
replace district_code = "49" if (district_code == "50")
replace id_sd = "2349" if (id_sd == "2350") 

* Merging Bilaspur, Korba, Jangjir, Kawardha, Rajnandgaon
gen comp_region = 0 //
	replace comp_region = 1 if inlist(district_code, "51", "52", "53", "54", "55")
replace merged_district = "51" if (comp_region == 1)
replace district_name = "District - Bilaspur and Rajnandgaon" if (comp_region == 1)
replace district_code = "51" if (comp_region == 1)
replace id_sd = "2351" if (comp_region == 1)

drop comp_region

* Merging Raipur, Mahasamund, Dhamtari --> Raipur
gen comp_region1 = 0 //
	replace comp_region = 1 if inlist(district_code, "57", "58", "59")
replace merged_district = "57" if (comp_region1 == 1)
replace district_name = "District - Raipur" if (comp_region1 == 1)
replace district_code = "57" if (comp_region1 == 1)
replace id_sd = "2357" if (comp_region1 == 1)

drop comp_region1

* Merging Bastar, Kanker, Dantewada --> Bastar
gen comp_region2 = 0 //
	replace comp_region2 = 1 if inlist(district_code, "61", "60", "62")
replace merged_district = "60" if (comp_region2 == 1)
replace district_name = "District - Bastar" if (comp_region2 == 1)
replace district_code = "60" if (comp_region2 == 1)
replace id_sd = "2360" if (comp_region2 == 1)

drop comp_region2

// Madhya Pradesh districts

* Merging Morena and Sheopur --> Morena
replace merged_district = cond(district_code == "01" | district_code == "02", "01", district_code)
replace district_name = "District - Morena" if (district_code == "01" | district_code == "02")
replace district_code = "01" if (district_code == "02")
replace id_sd = "2301" if (id_sd == "2302") 

* Merging Gwalior and Datia --> Gwalior and Datia
replace merged_district = cond(district_code == "04" | district_code == "05", "04", district_code)
replace district_name = "District - Gwalior and Datia" if (district_code == "04" | district_code == "05")
replace district_code = "04" if (district_code == "05")
replace id_sd = "2304" if (id_sd == "2305") 

* Merging Shahdol and Umaria --> Shahdol
replace merged_district = cond(district_code == "15" | district_code == "16", "15", district_code)
replace district_name = "District - Shahdol" if (district_code == "15" | district_code == "16")
replace district_code = "15" if (district_code == "16")
replace id_sd = "2315" if (id_sd == "2316") 

* Merging Mandsaur and Neemuch --> Mandsaur
replace merged_district = cond(district_code == "18" | district_code == "19", "18", district_code)
replace district_name = "District - Mandsaur" if (district_code == "18" | district_code == "19")
replace district_code = "18" if (district_code == "19")
replace id_sd = "2318" if (id_sd == "2319") 

* Merging West Nimar and Barwani --> West Nimar
replace merged_district = cond(district_code == "27" | district_code == "28", "27", district_code)
replace district_name = "District - West Nimar" if (district_code == "27" | district_code == "28")
replace district_code = "27" if (district_code == "28")
replace id_sd = "2327" if (id_sd == "2328") 

* Merging Hoshangabad and Harda --> Hoshangabad 
replace merged_district = cond(district_code == "36" | district_code == "37", "36", district_code)
replace district_name = "District - Hoshangabad" if (district_code == "36" | district_code == "37")
replace district_code = "36" if (district_code == "37")
replace id_sd = "2336" if (id_sd == "2337") 

* Merging Jabalpur and Katni --> Jabalpur
replace merged_district = cond(district_code == "38" | district_code == "39", "38", district_code)
replace district_name = "District - Jabalpur" if (district_code == "38" | district_code == "39")
replace district_code = "38" if (district_code == "39")
replace id_sd = "2338" if (id_sd == "2339") 

* Merging Mandla and Dindori --> Mandla
replace merged_district = cond(district_code == "41" | district_code == "42", "41", district_code)
replace district_name = "District - Mandla" if (district_code == "41" | district_code == "42")
replace district_code = "41" if (district_code == "42")
replace id_sd = "2341" if (id_sd == "2342") 

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/madhya_pradesh_2001_merge.dta", replace


**********
// Maharashtra: Total of 5 merges and changes
use "$csv_2001/maharashtra_2001_merge.dta", clear

* Merging Nandwarbar and Dhule --> Dhule
gen merged_district = cond(district_code == "01" | district_code == "02", "01", district_code)
replace district_name = "District - Dhule" if (district_code == "01" | district_code == "02")
replace district_code = "01" if (district_code == "02")
replace id_sd = "2701" if (id_sd == "2702") 

* Merging Akola and Washim --> Akola
replace merged_district = cond(district_code == "05" | district_code == "06", "05", district_code)
replace district_name = "District - Akola" if (district_code == "06" | district_code == "05")
replace district_code = "05" if (district_code == "06")
replace id_sd = "2705" if (id_sd == "2706")

* Merging Bhandara and Gondiya --> Bhandara
replace merged_district = cond(district_code == "10" | district_code == "11", "10", district_code)
replace district_name = "District - Bhandara" if (district_code == "10" | district_code == "11")
replace district_code = "10" if (district_code == "11")
replace id_sd = "2710" if (id_sd == "2711")

* Merging Parbhani and Hingoli --> Parbhani
replace merged_district = cond(district_code == "16" | district_code == "17", "16", district_code)
replace district_name = "District - Parbhani" if (district_code == "16" | district_code == "17")
replace district_code = "16" if (district_code == "17")
replace id_sd = "2716" if (id_sd == "2717")

* Merging Mumbai and Mumbai Suburban into Greater Bombay
replace merged_district = cond(district_code == "22" | district_code == "23", "22", district_code)
replace district_name = "District - Greater Bombay" if (district_code == "22" | district_code == "23")
replace district_code = "23" if (district_code == "22")
replace id_sd = "2722" if (id_sd == "2723")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)


save "$csv_2001/maharashtra_2001_merge.dta", replace

*****
// Manipur: merging Imphal East and Imphal West
use "$csv_2001/manipur_2001_merge.dta", clear

* Assiging Imphal East and Imphal West both merged_district code of 06
gen merged_district = cond(district_code == "06" | district_code == "07", "06", district_code)

* Renaming district
replace district_name = "District - Imphal" if (district_code == "06" | district_code == "07")
replace district_code = "06" if (district_code == "07")
replace id_sd = "1406" if (id_sd == "1407")

* Summing
collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/manipur_2001_merge.dta", replace


*****
// Meghalaya
use "$csv_2001/meghalaya_2001_merge.dta", clear

* Merging West and South Garo Hills --> West 
gen merged_district = cond(district_code == "01" | district_code == "03", "01", district_code)
replace district_name = "District - West Garo Hills" if (district_code == "01" | district_code == "03")
replace district_code = "01" if (district_code == "03")
replace id_sd = "1701" if (id_sd == "1703")

* Merging East Khasi, West Khasi and Ri-Bhoi Hills
replace merged_district = cond(district_code == "04" | district_code == "05" | district_code == "06", "04", district_code)
replace district_name = "District - East and West Khasi Hills" if (district_code == "04" | district_code == "05" | district_code == "06")
replace district_code = "04" if (district_code == "05" | district_code == "06")
replace id_sd = "1704" if (id_sd == "1705" | id_sd == "1706")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/meghalaya_2001_merge.dta", replace

*****
// Mizoram
use "$csv_2001/mizoram_2001_merge.dta", clear

* Merging Aizawl, Mamit, Kolasib, Champhai, Serchhip --> Aizawl
gen merged_district = cond(district_code == "03" | district_code == "01" | district_code == "02" | district_code == "04" | district_code == "05", "01", district_code)
replace district_name = "District - Aizawl" if (district_code == "03" | district_code == "01" | district_code == "02" | district_code == "04" | district_code == "05")
replace district_code = "01" if (district_code == "03" | district_code == "02" | district_code == "04" | district_code == "05")
replace id_sd = "1501" if (id_sd == "1502" | id_sd == "1503" | id_sd == "1504" | id_sd == "1505")

* Merging Lawngltai and Saiha --> Chhimtuipui
replace merged_district = cond(district_code == "07" | district_code == "08", "07", district_code)
replace district_name = "District - Chhimtuipui" if (district_code == "07" | district_code == "08")
replace district_code = "07" if (district_code == "08")
replace id_sd = "1507" if (id_sd == "1508")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/mizoram_2001_merge.dta", replace


**********
// Nagaland: merging Dimapur and Kohima
use "$csv_2001/nagaland_2001_merge.dta", clear

gen merged_district = cond(district_code == "06" | district_code == "07", "06", district_code)
replace district_name = "District - Kohima" if (district_code == "06" | district_code == "07")
replace district_code = "06" if (district_code == "07")
replace id_sd = "1306" if (id_sd == "1307")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/nagaland_2001_merge.dta", replace


**********
// Karnataka
use "$csv_2001/karnataka_2001_merge.dta", clear

* Bijapur and Bagal Kot --> Bijapur
gen merged_district = cond(district_code == "02" | district_code == "03", "02", district_code)
replace district_name = "District - Bijapur" if (district_code == "02" | district_code == "03")
replace district_code = "02" if (district_code == "03")
replace id_sd = "2902" if (id_sd == "2903")

* Raichur and Koppal --> Raichur
replace merged_district = cond(district_code == "06" | district_code == "07", "06", district_code)
replace district_name = "District - Raichur" if (district_code == "06" | district_code == "07")
replace district_code = "06" if (district_code == "07")
replace id_sd = "2906" if (id_sd == "2907")

* Dharwad, Gadag and Harveri --> Dharwad
replace merged_district = cond(district_code == "09" | district_code == "08" | district_code == "11", "08", district_code)
replace district_name = "District - Dharwad" if (district_code == "09" | district_code == "08" | district_code == "11")
replace district_code = "08" if (district_code == "09" | district_code == "11")
replace id_sd = "2908" if (id_sd == "2909" | id_sd == "2911")

* Bellary, Shimoga, Chitradurga, Davangare --> Bellary, Shimoga, Chitradurga
replace merged_district = cond(district_code == "12" | district_code == "13" | district_code == "15" | district_code == "14", "12", district_code)
replace district_name = "Bellary, Shimoga, Chitradurga" if (district_code == "12" | district_code == "13" | district_code == "15" | district_code == "14")
replace district_code = "12" if (district_code == "14" | district_code == "15" | district_code == "13")
replace id_sd = "2912" if (id_sd == "2914" | id_sd == "2915" | id_sd == "2913")

* Dakshina Kannada and Udupi --> Dakshina Kannada
replace merged_district = cond(district_code == "24" | district_code == "16", "16", district_code)
replace district_name = "District - Dakshina Kannada" if (district_code == "24" | district_code == "16")
replace district_code = "16" if (district_code == "24")
replace id_sd = "2916" if (id_sd == "2924")

* Mysore and Chamarajanagar --> Mysore
replace merged_district = cond(district_code == "26" | district_code == "27", "26", district_code)
replace district_name = "District - Mysore" if (district_code == "26" | district_code == "27")
replace district_code = "26" if (district_code == "27")
replace id_sd = "2926" if (id_sd == "2927")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)


save "$csv_2001/karnataka_2001_merge.dta", replace


**********
// Kerala: Merge Ernakulam and Idukki together
use "$csv_2001/kerala_2001_merge.dta", clear

gen merged_district = cond(district_code == "08" | district_code == "09", "08", district_code)
replace district_name = "District - Ernakulam and Idukki" if (district_code == "08" | district_code == "09")
replace district_code = "08" if (district_code == "09")
replace id_sd = "3208" if (id_sd == "3209")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/kerala_2001_merge.dta", replace


**********
// Orissa
use "$csv_2001/orissa_2001_merge.dta", clear

* Sambalpur, Bargarh, Debagarh, Jharsuguda --> Sambalpur
gen merged_district = cond(district_code == "03" | district_code == "04" | district_code == "01" | district_code == "02", "01", district_code)
replace district_name = "District - Sambalpur" if (district_code == "03" | district_code == "04" | district_code == "01" | district_code == "02")
replace district_code = "01" if (district_code == "02" | district_code == "03" | district_code == "04")
replace id_sd = "2101" if (id_sd == "2102" | id_sd == "2103" | id_sd == "2104")

* Baleshwar and Bhardrak --> Baleshwar
replace merged_district = cond(district_code == "08" | district_code == "09", "08", district_code)
replace district_name = "District - Baleshwar" if inlist(district_code, "08", "09")
replace district_code = "08" if (district_code == "09")
replace id_sd = "2108" if (id_sd == "2109")

* Cuttack, Jagatsinghapur, Jajapur, Kendrapara --> Cuttack
replace merged_district = cond(district_code == "12" | district_code == "13" | district_code == "11" | district_code == "10" , "10", district_code)
replace district_name = "District - Cuttack" if inlist(district_code, "10", "11", "12", "13")
replace district_code = "10" if inlist(district_code, "11", "12", "13")
replace id_sd = "2110" if inlist(id_sd, "2111", "2112", "2113")

* Dhenkanal and Anugul --> Dhenkanal
replace merged_district = cond(district_code == "14" | district_code == "15", "14", district_code)
replace district_name = "District - Dhenkanal" if inlist(district_code, "14", "15")
replace district_code = "14" if (district_code == "15")
replace id_sd = "2114" if (id_sd == "2115")

* Puri, Nayagarh, Khorda --> Puri
replace merged_district = cond(district_code == "18" | district_code == "16" | district_code == "17", "16", district_code)
replace district_name = "District - Puri" if inlist(district_code, "16", "17", "18")
replace district_code = "16" if inlist(district_code, "17", "18")
replace id_sd = "2116" if (id_sd == "2117" | id_sd == "2118")

* Ganjam and Gajapati --> Ganjam
replace merged_district = cond(district_code == "19" | district_code == "20", "19", district_code)
replace district_name = "District - Ganjam" if inlist(district_code, "19", "20")
replace district_code = "19" if (district_code == "20")
replace id_sd = "2119" if (id_sd == "2120")

* Kandhamal and Baudh --> Kandhamal 
replace merged_district = cond(district_code == "21" | district_code == "22", "21", district_code)
replace district_name = "District - Kandhamal" if inlist(district_code, "21", "22")
replace district_code = "21" if (district_code == "22")
replace id_sd = "2121" if (id_sd == "2122")

* Balangir and Sonapur --> Balangir
replace merged_district = cond(district_code == "24" | district_code == "23", "23", district_code)
replace district_name = "District - Balangir" if inlist(district_code, "23", "24")
replace district_code = "23" if (district_code == "24")
replace id_sd = "2123" if (id_sd == "2124")

* Kalahandi and Nuapada --> Kalandhi
replace merged_district = cond(district_code == "26" | district_code == "25", "25", district_code)
replace district_name = "District - Kalahandi" if inlist(district_code, "25", "26")
replace district_code = "25" if (district_code == "26")
replace id_sd = "2125" if (id_sd == "2126")

* Koraput, Malkangiri, Nabarangapur, Rayagada --> Koraput
gen comp_region = 0 //
	replace comp_region = 1 if inlist(district_code, "29", "30", "28", "27")
replace district_name = "District - Koraput" if (comp_region == 1)	
replace merged_district = "28" if (comp_region == 1)
replace district_code = "28" if (comp_region == 1)
replace id_sd = "2127" if (comp_region == 1)	

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)


save "$csv_2001/orissa_2001_merge.dta", replace


**********
// Punjab
use "$csv_2001/punjab_2001_merge.dta", clear

* Merge Bathinda and Mansa --> Bathinda
gen merged_district = cond(district_code == "14" | district_code == "15", "14", district_code) //
replace district_name = "District - Bathinda" if (district_code == "14" | district_code == "15") //
replace district_code = "14" if (district_code == "15")
replace id_sd = "0314" if (id_sd == "0315")

* Merge all other districts into composite region
gen composite_region = 0
replace composite_region = 1 if (inlist(district_code, "01", "02", "03", "04", "05", "06", "07") | inlist(district_code, "08", "09", "10", "11", "12", "13", "16", "17"))
replace merged_district = "02" if (composite_region == 1)
replace district_name = "Punjab composite region" if (composite_region == 1)
replace district_code = "02" if (composite_region == 1)
replace id_sd = "0302" if (composite_region == 1)

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/punjab_2001_merge.dta", replace


**********
// Rajasthan: merging 4 districts together
use "$csv_2001/rajasthan_2001_merge.dta", clear

* Merging Ganganagar and Hanumangarh --> Ganganagar
gen merged_district = cond(district_code == "01" | district_code == "02", "01", district_code)
replace district_name = "District - Ganganagar" if (district_code == "01" | district_code == "02")
replace district_code = "01" if (district_code == "02")
replace id_sd = "0801" if (id_sd == "0802")

* Merging Sawai Madhopur, Karauli, Dausi into the first
replace merged_district = cond(district_code == "09" | district_code == "10" | district_code == "11", "09", district_code)
replace district_name = "District - Sawai Madhopur" if (district_code == "09" | district_code == "10" | district_code == "11")
replace district_code = "09" if (district_code == "10" | district_code == "11")
replace id_sd = "0809" if (id_sd == "0810" | id_sd == "0811")

* Merging Udaipur and Rajsamand --> Udaipur
replace merged_district = cond(district_code == "25" | district_code == "26", "25", district_code)
replace district_name = "District - Udaipur" if (district_code == "25" | district_code == "26")
replace district_code = "25" if (district_code == "26")
replace id_sd = "0825" if (id_sd == "0826")

* Merging Kota and Baran --> Kota
replace merged_district = cond(district_code == "30" | district_code == "31", "30", district_code)
replace district_name = "District - Kota" if (district_code == "30" | district_code == "31")
replace district_code = "30" if (district_code == "31")
replace id_sd = "0830" if (id_sd == "0831")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/rajasthan_2001_merge.dta", replace


**********
// Tamil Nadu: 7 merges 
use "$csv_2001/tamil_nadu_2001_merge.dta", clear

* Merging Kancheepuram and Thiruvallur --> Kancheepuram
gen merged_district = cond(district_code == "01" | district_code == "03", "01", district_code)
replace district_name = "District - Kancheepuram" if (district_code == "01" | district_code == "03")
replace district_code = "01" if (district_code == "03")
replace id_sd = "3301" if (id_sd == "3303")

* Merging Salem and Namakkal --> Salem
replace merged_district = cond(district_code == "08" | district_code == "09", "08", district_code)
replace district_name = "District - Salem" if (district_code == "08" | district_code == "09")
replace district_code = "08" if (district_code == "09")
replace id_sd = "3308" if (id_sd == "3309")

* Merging Tiruch (15), Karur (14), Perambalur (16), Ariyalur (17) --> Tiruch
replace merged_district = cond(district_code == "14" | district_code == "15" | district_code == "16" | district_code == "17", "14", district_code)
replace district_name = "District - Tiruchchirappalli" if (district_code == "14" | district_code == "15" | district_code == "16" | district_code == "17")
replace district_code = "14" if (district_code == "15" | district_code == "16" | district_code == "17")
replace id_sd = "3314" if (id_sd == "3315" | id_sd == "3316" | id_sd == "3317")

* Merging Cuddalore and Viluppuram --> South Arcot
replace merged_district = cond(district_code == "18" | district_code == "07", "07", district_code)
replace district_name = "District - South Arcot" if (district_code == "18" | district_code == "07")
replace district_code = "07" if (district_code == "18")
replace id_sd = "3307" if (id_sd == "3318")

* Merge Thanjavur, Thiruvarur, Nagapattinam --> Thanjavur
replace merged_district = cond(district_code == "21" | district_code == "20" | district_code == "19", "19", district_code)
replace district_name = "District - Thanjavur" if (district_code == "21" | district_code == "20" | district_code == "19")
replace district_code = "19" if (district_code == "20" | district_code == "21")
replace id_sd = "3319" if (id_sd == "3320" | id_sd == "3321")

* Merge Madurai and Theni --> Madurai
replace merged_district = cond(district_code == "24" | district_code == "25", "24", district_code)
replace district_name = "District - Madurai" if (district_code == "24" | district_code == "25")
replace district_code = "24" if (district_code == "25")
replace id_sd = "3324" if (id_sd == "3325")

* Merge Ramanathapuram and Sivaganga --> Ramanathapam and Pasumpon
replace merged_district = cond(district_code == "27" | district_code == "23", "23", district_code)
replace district_name = "District - Ramanathapuram and Pasumpon" if (district_code == "23" | district_code == "27")
replace district_code = "27" if (district_code == "23")
replace id_sd = "3323" if (id_sd == "3327")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/tamil_nadu_2001_merge.dta", replace


**********
// Tripura: Merging North, South and Dhalai
use "$csv_2001/tripura_2001_merge.dta", clear

gen merged_district = cond(district_code == "02" | district_code == "03" | district_code == "04", "02", district_code)
replace district_name = "District - North and South Tripura" if (district_code == "02" | district_code == "03" | district_code == "04")
replace district_code = "02" if (district_code == "03" | district_code == "04")
replace id_sd = "1602" if (id_sd == "1603" | id_sd == "1604")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)

save "$csv_2001/tripura_2001_merge.dta", replace


********************************************************************************
// Uttar Pradesh: Over ~ 20 merges
use "$csv_2001/uttar_pradesh_2001_merge.dta", clear

append using "$csv_2001/uttarakhand_2001_merge.dta"
* Note Uttarakhand was formerly known as Uttaranachal

drop id_sd

* Sorting out Uttarakhand district codes to be additive to Uttar Pradesh's
gen district_code_numeric = real(district_code) // conerting district code to numeric
replace district_code_numeric = district_code_numeric + 71  if (state_code == "05")
replace district_code = string(district_code_numeric, "%02.0f") if (state_code == "05")
drop district_code_numeric

* Changing Chhattisgarh state code to Madhya Pradesh's
replace state_code = "09" if (state_code == "05")
gen id_sd = state_code + district_code

// Uttarakhand districts

* Merging for composite region (Chamoli, Rudraprayag, Tehri Garhwal, Garhwal, Nainital, Pithoragarh, Champawat, Udham Singh)
gen composite_region = 0 //
	replace composite_region = 1 if inlist(district_code, "73", "74", "75", "77", "82", "78", "81", "83")
gen merged_district = "73" if (composite_region == 1)
replace district_name = "Uttarakhand composite region" if (composite_region == 1)
replace district_code = "73" if (composite_region == 1)
replace id_sd = "0973" if (composite_region == 1)

* Merging Almora and Begeshwar --> Almora
replace merged_district = cond(district_code == "80" | district_code == "79", "79", district_code)
replace district_name = "District - Almora" if (district_code == "80" | district_code == "79")
replace district_code = "79" if (district_code == "80")
replace id_sd = "0979" if (id_sd == "0980")

// Uttar Pradesh

* Merge Moradabad and Jyotiba Phule Nagar --> Moradabad
replace merged_district = cond(district_code == "04" | district_code == "06", "04", district_code)
replace district_name = "District - Moradabad" if (district_code == "04" | district_code == "06")
replace district_code = "04" if (district_code == "06")
replace id_sd = "0904" if (id_sd == "0906")

* Merge Meerut and Baghpat --> Meerut
replace merged_district = cond(district_code == "07" | district_code == "08", "07", district_code)
replace district_name = "District - Meerut" if (district_code == "07" | district_code == "08")
replace district_code = "07" if (district_code == "08")
replace id_sd = "0907" if (id_sd == "0908")

* Merge Ghaziabad, Bulandshaher, Gautam Buddha nagar --> Ghaziabad and Bulandshahr
replace merged_district = cond(district_code == "09" | district_code == "11" | district_code == "10", "09", district_code)
replace district_name = "District - Ghaziabad and Bulandshahr" if (district_code == "09" | district_code == "10" | district_code == "11")
replace district_code = "09" if (district_code == "10" | district_code == "11")
replace id_sd = "0909" if (id_sd == "0910" | id_sd == "0911")

* Aligarh, Mathura, Hathras --> Aligarh and Mathura 
replace merged_district = cond(district_code == "12" | district_code == "13" | district_code == "14", "12", district_code)
replace district_name = "District - Aligarh and Mathura" if (district_code == "12" | district_code == "13" | district_code == "14")
replace district_code = "12" if (district_code == "13" | district_code == "14")
replace id_sd = "0912" if (id_sd == "0913" | id_sd == "0914")

* Mainpuri and Etawah and Auraiya --> Mainpuri and Etawah
replace merged_district = cond(district_code == "18" | district_code == "31" | district_code == "32", "18", district_code)
replace district_name = "District - Mainpuri and Etawah" if (district_code == "18" | district_code == "31" | district_code == "32")
replace district_code = "18" if (district_code == "31" | district_code == "32")
replace id_sd = "0918" if (id_sd == "0931" | id_sd == "0932")

* Rae Bareli, Sultanpur, Fatehpur --> RSF
replace merged_district = cond(district_code == "28" | district_code == "49" | district_code == "42", "28", district_code)
replace district_name = "District- Rae, Sultanpur, Fatehpur" if (district_code == "28" | district_code == "49" | district_code == "42")
replace district_code = "28" if (district_code == "49" | district_code == "42")
replace id_sd = "0928" if (id_sd == "0942" | id_sd == "0949")

* Farrukhabad, Kannauj --> Farrukhabad
replace merged_district = cond(district_code == "30" | district_code == "29", "29", district_code)
replace district_name = "District - Farrukhabad" if (district_code == "29" | district_code == "30")
replace district_code = "29" if (district_code == "30")
replace id_sd = "0929" if (id_sd == "0930")

* Kanpur Dehat, Kanpur Nagar --> Kanpur Dehat and Nagar
replace merged_district = cond(district_code == "33" | district_code == "34", "33", district_code)
replace district_name = "District - Kanpur (Nagar and Dehat)" if (district_code == "33" | district_code == "34")
replace district_code = "33" if (district_code == "34")
replace id_sd = "0933" if (id_sd == "0934")

* Hamirpur and Mahoba --> Hamirpur
replace merged_district = cond(district_code == "38" | district_code == "39", "38", district_code)
replace district_name = "District - Hamirpur" if (district_code == "38" | district_code == "39")
replace district_code = "38" if (district_code == "39")
replace id_sd = "0938" if (id_sd == "0939")

* Banda, Chitrakoot --> Banda
replace merged_district = cond(district_code == "40" | district_code == "41", "40", district_code)
replace district_name = "District - Banda" if (district_code == "40" | district_code == "41")
replace district_code = "40" if (district_code == "41")
replace id_sd = "0940" if (id_sd == "0941")

* Allahabad, Kaushambi --> Allahabad
replace merged_district = cond(district_code == "45" | district_code == "44", "44", district_code)
replace district_name = "District - Allahabad" if (district_code == "44" | district_code == "45")
replace district_code = "44" if (district_code == "45")
replace id_sd = "0944" if (id_sd == "0945")

* Barabanki, Faizabad, Ambedkar Nagar, Azamgarh --> Barabanki, Faizabad, Azamgarh
replace merged_district = cond(district_code == "46" | district_code == "47" | district_code == "48" | district_code == "61", "46", district_code)
replace district_name = "Barabanki, Faizabad, Azamgarh" if (district_code == "46" | district_code == "47" | district_code == "48" | district_code == "61")
replace district_code = "46" if (district_code == "47" | district_code == "48" | district_code == "61")
replace id_sd = "0946" if (id_sd == "0947" | id_sd == "0948" | id_sd == "0961")

* Bahraich and Shrawasti --> Bahraich
replace merged_district = cond(district_code == "50" | district_code == "51", "50", district_code)
replace district_name = "District - Bahraich" if (district_code == "50" | district_code == "51")
replace district_code = "50" if (district_code == "51")
replace id_sd = "0950" if (id_sd == "0951")

* Gonda and Balrampur --> Gonda
replace merged_district = cond(district_code == "53" | district_code == "52", "52", district_code)
replace district_name = "District - Gonda" if (district_code == "52" | district_code == "53")
replace district_code = "52" if (district_code == "53")
replace id_sd = "0952" if (id_sd == "0953")

* Siddharth Nagar, Basti, Sant Kabir --> Siddharth Nagar and Basti
replace merged_district = cond(district_code == "54" | district_code == "55" | district_code == "56", "54", district_code)
replace district_name = "District - Siddharth Nagar and Basti" if (district_code == "54" | district_code == "55" | district_code == "56")
replace district_code = "54" if (district_code == "55"| district_code == "56")
replace id_sd = "0954" if (id_sd == "0955" | id_sd == "0956")

* Deoria and Kushinagar --> Deoria 
replace merged_district = cond(district_code == "59" | district_code == "60", "59", district_code)
replace district_name = "District - Deoria" if (district_code == "59" | district_code == "60")
replace district_code = "59" if (district_code == "60")
replace id_sd = "0959" if (id_sd == "0960")

* Varanasi, Chandauli , Sant Ravidas --> Varanasi
replace merged_district = cond(district_code == "67" | district_code == "66" | district_code == "68", "66", district_code)
replace district_name = "District - Varanasi" if (district_code == "66" | district_code == "67" | district_code == "68")
replace district_code = "66" if (district_code == "67" | district_code == "68")
replace id_sd = "0966" if (id_sd == "0967" | id_sd == "0968")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)


save "$csv_2001/uttar_pradesh_2001_merge.dta", replace

********************************************************************************
// West Bengal
use "$csv_2001/west_bengal_2001_merge.dta", clear

* Uttar Dinajpur, Dakshin Dinajpur --> West Dinajpur 
gen merged_district = cond(district_code == "04" | district_code == "05", "04", district_code)
replace district_name = "District - West Dinajpur" if (district_code == "04" | district_code == "05")
replace district_code = "04" if (district_code == "05")
replace id_sd = "1904" if (id_sd == "1905")

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_level)


save "$csv_2001/west_bengal_2001_merge.dta", replace



********************************************************************************
  ****************************************************************************
********************************************************************************
  
// APPENDING 2001 DATASETS

* Appending 2001 merge datasets
clear all
cd "$csv_2001"

local states_2001b "arunachal_pradesh assam bihar goa gujarat haryana himachal_pradesh karnataka kerala madhya_pradesh maharashtra manipur meghalaya mizoram nagaland orissa punjab rajasthan sikkim tamil_nadu tripura uttar_pradesh west_bengal andaman_nicobar chandigarh dadra_nagar daman_diu delhi lakshadweep pondicherry"

use "andhra_pradesh_2001_merge.dta", clear

foreach state in `states_2001b' {
	append using "`state'_2001_merge.dta"
}

* Dropping duplicate observations for when only one district in the state

* Fixing Delhi composite regions here - just want to keep Delhi total as a state, was formerly one state and district in 1991
drop if inlist(id_sd, "0701", "0702", "0703", "0704", "0705", "0706", "0707", "0708", "0709")

drop if id_sd == "0401" // Chandigarh
drop if id_sd == "2601" // Dadra and Nagar Haveli
drop if id_sd == "3101" // Lakdshadweep

* Fixing if duplicate district names but in different states
replace district_name = "district-aurangabadbihar" if (id_sd == "1034")
replace district_name = "district-aurangabadmaha" if (id_sd == "2719")
replace district_name = "district-hamirpurhp" if (id_sd == "0206")
replace district_name = "district-hamirpurup" if (id_sd == "0938")
replace district_name = "district-raigarhmp" if (id_sd == "2349")
replace district_name = "district-raigarhmaha" if (id_sd == "2724")


tempfile all_2001
save `all_2001', replace

* Merging education groups so same categories as 1991

* First, need to generate a category for 'Literate but without education category' = category 'Literate' - all other literate categories  


*****

preserve 

drop if inlist(education_level, 1, 2, 8)

gen edu_category = 0 //
	replace edu_category = 1 if (education_level == 3) // 'Literate'
	replace edu_category = 2 if inlist(education_level, 4, 5, 6, 7) // All other literate categories

sort state_code district_code rural
	
collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural edu_category)


* Now, tagging each observation when edu_category = 1 to be + 1, then when edu_category = 2 to be -1.

gen tag = 0 //
	replace tag = 1 if (edu_category == 1)
	replace tag = -1 if (edu_category == 2)

* Now setting all variables when edu_category = 2 to be negative	
foreach var of varlist *_total *_female *_male total_pop {
	replace `var' = `var' * tag
}

* Now collapsing again - with the negative values for when edu_category == 2, we are essentially subtracting them from when edu_category == 1. Sanity checked!
collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural edu_category)

tempfile edu_literate_temp
save `edu_literate_temp', replace

restore

*****

*
use `all_2001', clear
append using `edu_literate_temp'

sort state_code district_code district_name rural education_level

* Dropping if education level is 'literate'
drop if education_level == 3

gen education_category = 0
	replace education_category = 1 if (education_level == 2)
	replace education_category = 2 if (education_level == 4 | missing(education_level))
	replace education_category = 3 if inlist(education_level, 5, 7)
	replace education_category = 4 if inlist(education_level, 1, 6)
	replace education_category = 5 if (education_level == 8)
	
label define education_category_lbl 1 "Illiterate" 2 "Literate but below matric/secondary" 3 "Matric/secondary but below graduate" 4 "Graduate and above" 5 "Total"
label values education_category education_category_lbl	

collapse (sum) *_total *_female *_male total_pop married_women1519 married_women2024 married_women2529 married_women3034 married_womenall births_last_year1519 births_last_year2024 births_last_year2529 births_last_year3034 births_last_yearall female_pop1519 female_pop2024 female_pop2529 female_pop3034 female_popall total_non_workers male_non_workers female_non_workers non_worker_discount *_female2 *_female4 *_male2 *_male4 total_migrants2 total_migrants4 *_total2 *_total4, by(state_code district_code id_sd district_name merged_district rural education_category)

// Now constructing the shares/employment here:

* Constructing employment shares 
gen employment = main_pop_total/total_pop
gen male_employment = main_pop_male/pop_male 
gen female_employment = main_pop_female/pop_female

* Constructing industry shares
gen cultivator_share = cultivators_total/main_pop_total
gen agriculture_share = agriculture_total/main_pop_total
gen livestock_share = livestock_total/main_pop_total
gen mining_share = mining_total/main_pop_total
gen household_share = household_total/main_pop_total
gen manu_industry_share = manu_industry_total/main_pop_total
gen construction_share = construction_total/main_pop_total	
gen trade_share = trade_total/main_pop_total
gen transport_share = transport_total/main_pop_total
gen other_service_share = other_service_total/main_pop_total

* Adding 2001 dummy 
gen year = 2
label define year_lbl 1 "1991" 2 "2001"
label values year year_lbl

* Cleaning up District names for matching later
replace district_name = trim(district_name)
replace district_name = lower(district_name)
replace district_name = subinstr(district_name, " ", "", .)
replace district_name = regexr(district_name, "[0-9]+", "") // Removing numbers from district name

save "$working_data/all_2001.dta", replace




********************************************************************************
  ****************************************************************************
********************************************************************************

// APPENDING 1991 AND 2001 TOGETHER

* A bit complicated to match regions in 2001 to 1991 (have differing state and district codes order); region names changed/have mismatching spellings, so first fix the names. Then, will match observations by region names. Set to have 1991 state and district codes

/* Using reclink package to try and match district names - slight variations between 1991 and 2001 (need to do because state and district codes are inconsistent)

This will help me see which district names are still not matched

* Load 1991 dataset
use "$working_data/all_1991.dta", clear
gen id1 = _n  // Create unique ID for 1991 dataset
recast str50 district_name // shortening 
save "$csv_1991/temp_all_1991.dta", replace  // Save with id1

* Load 2001 dataset
use "$working_data/all_2001.dta", clear
gen id2 = _n  // Create unique ID for 2001 dataset
recast str50 district_name
save "$csv_2001/temp_all_2001.dta", replace  // Save with id2

* Use reclink to fuzzy match district names
reclink district_name using "$csv_1991/temp_all_1991.dta", idm(id2) idu(id1) gen(matchscore)

* Sort by matchscore to evaluate matches
sort matchscore
list district_name if matchscore < 0.99  // Review good matches */



use "$working_data/all_1991.dta", clear

append using "$working_data/all_2001.dta"


* Dropping state observations of new states formed in 2001 - have formed composite regions - don't keep as separate total
drop if inlist(district_name, "state-chhattisgarh", "state-jharkhand", "state-uttaranchal")

* Sorting out Delhi - checked against raw Excel dataset
drop if (id_sd == "3000") & (district_name == "state-delhi") 
replace district_name = "state-delhi" if (district_name == "state-delhidistrict")

* Correcting spelling mismatches or district name changes: - actually use district name to replace - might not work otherwise

replace district_name = "district-kolkata" if (district_name == "district-calcutta") // Calcutta --> Kolkata
replace district_name = "district-dhaulpur" if (district_name == "district-dholpur") // Dhaulpur --> Dholpur
replace district_name = "district-dindigul" if (district_name == "district-dindigul-quaid-e-milleth") // Dindigul

// District name changes
replace district_name = "district-kancheepuram" if (district_name == "district-chengai-anna")
replace district_name = "district-madras" if (district_name == "district-chennai") 
replace district_name = "district-tirunelveli" if (district_name == "district-tirunelvelikattabomman")
replace district_name = "district-tiruvannamalai" if (district_name == "district-tiruvannamalaisambuvarayar")
replace district_name = "district-kamarajar" if (district_name == "district-virudhunagar")
replace district_name = "district-phulabani" if (district_name == "district-kandhamal") // from searching, Phulabani divided into Boudh and Kandhamal, but cannot identify Boudh, or find in Appendix spreadhseet
replace district_name = "district-vellore" if (district_name == "district-northarcot-ambedker")
replace district_name = "district-thiruvananthapuram" if (district_name == "district-trivandrum")
replace district_name = "district-nilgiris" if inlist(district_name, "district-nilgiri", "district-thenilgiris")
replace district_name = "district-erode" if (district_name == "district-periyar")
replace district_name = "district-thoothukkudi" if (district_name == "district-chidambaranar")


replace district_name = "state-andaman&nicobarislands" if (district_name == "state-andamanandnicobarislands")
replace district_name = "state-chandigarh" if (district_name == "state-chandigarhu.t.")
replace district_name = "state-lakshadweep" if (district_name == "state-lakshadweepu.t.")
replace district_name = "state-pondicherry" if (district_name == "state-pondicherryu.t.")
replace district_name = "state-dadra&nagarhaveli" if (district_name == "state-dadraandnagarhaveli")
replace district_name = "district-lahul&spiti" if (district_name == "district-lahulandspiti")
replace district_name = "district-pondicherry" if (district_name == "district-pondicherrydistrict") 
replace district_name = "state-daman&diu" if (district_name == "state-damananddiu")

* Sikkim
replace district_name = "district-east" if (district_name == "district-eastdistrict")
replace district_name = "district-west" if (district_name == "district-westdistrict")
replace district_name = "district-north" if (district_name == "district-northdistrict")
replace district_name = "district-south" if (district_name == "district-southdistrict")


* Some districts only have rural or urban parts (all values set to 0) - want to drop if don't have urban region (analysis is does by urban) in either 1991 or 2001 - need for both periods to do analysis

drop if (district_name == "district-changlang")
drop if (district_name == "district-ukhrul")
drop if (district_name == "district-uppersubansiri")
drop if (district_name == "district-tawang")
drop if (district_name == "district-eastkameng")
drop if (district_name == "district-kinnaur")
drop if (district_name == "district-lahul&spiti")
drop if (district_name == "district-nicobars")
drop if (district_name == "district-senapati")
drop if (district_name == "district-tamenglong")

* Count the number of observations per district
gen obs_count = .
bysort district_name (district_name): replace obs_count = _N


********************************************************************************

* Fixing vars

* Replacing main_pop_ with main_pop_2

/* If main_pop_total2 is not missing (1991 observations - for which main_pop is self-constructed with the sum of workers across all industries rather than the mismatching census figures), then replace main_pop_total with the self-constructed figure, and then drop the _2 vars. 
*/

replace main_pop_total = main_pop_total2 if (!missing(main_pop_total2))
replace main_pop_male = main_pop_male2 if (!missing(main_pop_male2))
replace main_pop_female = main_pop_female2 if (!missing(main_pop_female2))

drop main_pop_total2 main_pop_male2 main_pop_female2

drop merged_district obs_count


// Wanting State and district codes to be the same - take on the 1991 state and district codes - a bit more fiddly because of mismatched variable types 

// State code
gen state_code_1991 = . 
gen state_code_1991str = string(state_code_1991) // because else mismatch between variable types - making variable generated a string
replace state_code_1991str = state_code if (year == 1) // takes value of state code if a 1991 obs

gen state_code_1991num = real(state_code_1991str) // To use max function, can't be a string
bys district_name: egen state_max_1991 = max(state_code_1991num) // Var takes on value of 1991 state code for all observations
gen state_1991 = string(state_max_1991, "%02.0f") // Making sure 2 digits SC

replace state_code = state_1991

drop state_code_1991 state_code_1991str state_code_1991num state_max_1991 state_1991

// District code
gen district_code_1991 = .
gen district_code_1991str = string(district_code_1991)
replace district_code_1991str = district_code if (year == 1) // taking on 1991 district code value

gen district_code_1991num = real(district_code_1991str)
bys district_name: egen district_max_1991 = max(district_code_1991num)
gen district_1991 = string(district_max_1991, "%02.0f")

replace district_code = district_1991 // why are there 5070 changes made? - some coincidentally the same district

drop district_code_1991 district_code_1991str district_code_1991num district_max_1991 district_1991

drop id_sd

gen id_sd = state_code + district_code

sort state_code district_code id_sd rural education_category

save "$working_data/panel_states.dta", replace



********************************************************************************
   **************************************************************************
********************************************************************************
   
// ADDING TARIFFS

import delimited "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Data/wits_tariff.csv", clear

save "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Data/wits_tariff.dta", replace
	
* MFN and AHS have a correlation of 1 for 1990 and 1997, 0.9982 for 2001.
drop mfn_*



* To have duplicate of metal to also assign to construction:
preserve

keep if product_type == "Metals"
replace product_type = "Metal" if (product_type == "Metals")

tempfile metal_temp
save `metal_temp'

restore

append using `metal_temp'

* Generating industry group dummies - will collapse mean by this
gen industry = . 

replace industry = 1 if inlist(product_type, "Agricultural raw materials", "Vegetable") // Combining cultivators and agriculture for tariffs

replace industry = 2 if inlist(product_type, "Animal ", "Hides and Skins")

replace industry = 3 if inlist(product_type, "Minerals", "Fuels", "Metals", "Ores and Metals", "Fuel")

replace industry = 4 if inlist(product_type, "Chemicals", "Manufactures", "Mach and Elec", "Textiles and Clothing", "Plastic or rubber")

replace industry = 5 if inlist(product_type, "Wood", "Stone and Glass", "Metal")

replace industry = 6 if inlist(product_type, "Transportation", "Machinery and Transport equipment ")

replace industry = 7 if inlist(product_type, "Consumer goods")
* Wholesale and trade tariffs go in the opposite direction

label define industry_lbl 1 "Cultivators and agriculture" 2 "Livestock" 3 "Mining" 4 "Manufacturing" 5 "Construction" 6 "Transport" 7 "Wholesale and retail trade" 8 "Household manufacturing"
label values industry industry_lbl


/* So far, have left out other services
If I wanted to have products being assigned to multiple industries --> duplicate products and assign? e.g. duplicate metals and also assign to manufacturing 
Some ambiguity - what to assign to wholesale and retail Trade, hotel and restaurants
Do I want to have weights for this - how much of each product? Weighted average reflects how much product is traded - so constructing the mean seems to be fairly straightforward simplification*/

collapse (mean) ahs_*, by (industry)

drop if missing(industry)

* Wanting to duplicate Manufacturing tariff values for household manufacturing
preserve 

keep if (industry == 4)
replace industry = 8 if (industry == 4)

tempfile household_manu_temp
save `household_manu_temp'

restore 

append using `household_manu_temp'


// A little graph in between

preserve

bys industry: gen ahs_1997_change = 0 //
	replace ahs_1997_change = ahs_wghtd_1990 - ahs_wghtd_1997
	
bys industry: gen ahs_2001_change = 0 //
	replace ahs_2001_change = ahs_wghtd_1990 - ahs_wghtd_2001

* 1997	
graph hbar ahs_1997_change, ///
    over(industry) ytitle("% change in AHS applied tariff 1991 to 1997") ///
	graphregion(color(white))
	
graph export "$output/Prelim output/tariff_bar_1997.jpg", replace 	

*2001
graph hbar ahs_2001_change, ///
    over(industry) ytitle("% change in AHS applied tariff 1991 to 2001") ///
	graphregion(color(white))
	
graph export "$output/Prelim output/tariff_bar_2001.jpg", replace 

restore 	

* Reshaping and altering tariff data so ready to merge (to long format first)
reshape long ahs_wghtd_, i(industry) j(year)

* Reshaping to wide again so that now, my years are rows and each column is the industry group
reshape wide ahs_wghtd, i(year) j(industry)

* Setting 1990 year to be 1991 - for merging purposes
replace year = 1991 if (year == 1990)

* So I will need to keep both the 1997 (instrument) and 2001 (actual) tariffs, but will be merging into my state dataset where I only have the 2001 ones. Try creating more vars which have tariff_1997 values - take on actual value if year set to be 2001 and set as missing if year is 1991:

forvalues i = 1/8  {
	gen tariff7_`i' = ahs_wghtd_`i' if (year == 1997)
	egen max_tariff7_`i' = max(tariff7_`i')
	replace tariff7_`i' = max_tariff7_`i'
	replace tariff7_`i' = . if (year == 1991)
	drop max_tariff7_`i'
}

* Renaming variables
rename ahs_wghtd_1 cultivator_tariff
rename ahs_wghtd_2 livestock_tariff
rename ahs_wghtd_3 mining_tariff
rename ahs_wghtd_4 manufacturing_tariff
rename ahs_wghtd_5 construction_tariff
rename ahs_wghtd_6 transport_tariff
rename ahs_wghtd_7 wholesale_trade_tariff
rename ahs_wghtd_8 housing_manu_tariff

rename tariff7_1 cultivator_1997_tariff
rename tariff7_2 livestock_1997_tariff
rename tariff7_3 mining_1997_tariff
rename tariff7_4 manufacturing_1997_tariff
rename tariff7_5 construction_1997_tariff
rename tariff7_6 transport_1997_tariff
rename tariff7_7 wholesale_trade_1997_tariff
rename tariff7_8 housing_manu_1997_tariff

drop if year == 1997

label variable cultivator_tariff "1991 and 2001 tariff values for cultivator industry accordingly"
label variable cultivator_1997_tariff "1991 and 1997 (for 2001) tariff values for cultivator industry accordingly"


save "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Data/wits_tariff.dta", replace


*****
* Merging datasets - many to 1 merge

use "$working_data/panel_states.dta", clear

merge m:1 year using "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Data/wits_tariff.dta"


* Sorting out (will not merge to all - the tariff values were incorporated a bit weirdly and wouldn't match to actual observations, so set the smallest tariff value to be for 2001, and the largest for 1991 - apart from wholesale and retail trade, which was the only industry for which this flipped).

foreach var in cultivator_tariff livestock_tariff mining_tariff manufacturing_tariff construction_tariff transport_tariff housing_manu_tariff {
	
	egen `var'_min = min(`var')
	replace `var' = `var'_min if (year == 2) // setting all 2001 tariff values

	egen `var'_max = max(`var')
	replace `var' = `var'_max if (year == 1) // setting all 1991 tariff values
	
	drop `var'_min `var'_max
}

* Doing wholesale and retail trade manually because 1991 tariff < 2001 tariff
egen wholesale_trade_1991 = min(wholesale_trade_tariff)
replace wholesale_trade_tariff = wholesale_trade_1991 if (year == 1)

egen wholesale_trade_2001 = max(wholesale_trade_tariff)
replace wholesale_trade_tariff = wholesale_trade_2001 if (year == 2)
drop wholesale_trade_1991 wholesale_trade_2001


* Setting 1997_tariff vars for all 2001 observations and to take on 1991 tariff value if obs is 1991
foreach var in cultivator livestock mining manufacturing construction transport wholesale_trade housing_manu {
	
	egen `var'_1997_tariffmax = max(`var'_1997_tariff)
	replace `var'_1997_tariff = `var'_1997_tariffmax if (year == 2) // setting all 2001 tariff values
	drop `var'_1997_tariffmax
	
	* Now need to set 1991 observations to take on 1991 tariff values
	replace `var'_1997_tariff = `var'_tariff if (year == 1)
}

drop if missing(state_code) & missing(district_code)

*****
* Constructing interaction shares - shift share - will come back to ssaggregate

save "$working_data/panel_states.dta", replace




********************************************************************************
  ****************************************************************************

// SETTING UP PANEL

* CAUTION: IF RUNNING THE DO-FILE IN PARTS --> RIGHT NOW, HAVE ALREADY SAVED DATASET WITH BASELINE SHARE - EITHER DON'T RUN SECTION OR RERUN WHOLE FILE 
use "$working_data/panel_states.dta", clear

* Generating unique identifier considering district_name, education category and urban/rural. Each unique combination becomes a panel
egen district_breakdown = group(district_name education_category rural), label

xtset district_breakdown year


// Generating baseline shares: Was working before --> now can't find share?
foreach var in cultivator agriculture household livestock mining manu_industry construction trade transport other_service {
	gen `var'_baseline_share = `var'_share if (year == 1)
	replace `var'_baseline_share = `var'_baseline_share[_n-1] if missing(`var'_baseline_share)
}

* Agriculture tariff to make easier for interacting:
gen agriculture_tariff = cultivator_tariff
gen agriculture_1997_tariff = cultivator_1997_tariff


********* 

// Generating instrument and treatment

* Treatment
bys district_breakdown: gen shift_share_treat = . ///

replace shift_share_treat = ///
	cultivator_tariff * cultivator_share + ///
	agriculture_tariff * agriculture_share + ///
	livestock_tariff * livestock_share + ///
	mining_tariff * mining_share + ///
	manufacturing_tariff * manu_industry_share + ///
	construction_tariff * construction_share + ///
	transport_tariff * transport_share + ///
	wholesale_trade_tariff * trade_share + ///
	housing_manu_tariff * household_share ///

label variable shift_share_treat "Exposure to trade (sum term of industry employment share interacted with current tariff rate)"	
	
* Instrument	
bys district_breakdown: gen shift_share_instr = ///
    cultivator_1997_tariff * cultivator_baseline_share + ///
	agriculture_1997_tariff * agriculture_baseline_share + ///
    livestock_1997_tariff * livestock_baseline_share + ///
	mining_1997_tariff * mining_baseline_share + ///
	manufacturing_1997_tariff * manu_industry_baseline_share + ///
	construction_1997_tariff * construction_baseline_share + ///
	transport_1997_tariff * transport_baseline_share + ///
	wholesale_trade_1997_tariff * trade_baseline_share + ///
	housing_manu_1997_tariff * household_baseline_share	
	
label variable shift_share_instr "Exposure to trade (summation term) using 1997 tariff values for 2001 obs"		
	
// Taking the log of people employed (not ln employment share, but of people employed)
gen ln_employed = ln(main_pop_total)
gen ln_femployed = ln(main_pop_female)
gen ln_memployed = ln(main_pop_male)

label var ln_employed "Log of number of people in main work"
label var ln_femployed "Log of number of women in main work"
label var ln_memployed "Log of number of men in main work"

// Taking the log of population 
gen ln_pop = ln(total_pop)
gen ln_fpop = ln(pop_female)
gen ln_mpop = ln(pop_male)

label var ln_pop "Log of number of total population"
label var ln_fpop "Log of female population"
label var ln_mpop "Log of male population"


* Also need to generate sum of shares control (interaction of sum of baseline shares with time period 2 dummy)
gen period_2 = 0 // time period dummy
	replace period_2 = 1 if (year == 2)
	
gen sum_baseline_shares = cultivator_baseline_share + agriculture_baseline_share + livestock_baseline_share + mining_baseline_share + manu_industry_baseline_share + construction_baseline_share + transport_baseline_share + trade_baseline_share + household_baseline_share	

gen sum_share_period = sum_baseline_shares * period_2 

label var sum_share_period "Interaction of sum of baseline shares with time period 2 dummy indicator"

* For analysis in regression, generating numerical version of district_name
encode district_name, gen(district_name_num)


**********

// To create gender-specific shift_share 

/* To construct instruments by gendered exposure to shocks, will multiply industry employment measure by the initial period female/male share of employment in each industry. This comes down to: sum of (the initial number of `female' workers in an industry in the region)/(the total number of initial workers in the region), interacted with the 1991/1997 tariff, for each industry.

Treatment will take a similar form of: (the current number of `female' workers in an industry in a region)/(the total number of current workers in the region), interacted with the tariff for that industry 

*/

* First, need to create the gender-specific shares: (number of female workers in the industry/total number of workers in the region)


rename cultivators_female cultivator_female 
rename cultivators_male cultivator_male 

* Female
foreach v in cultivator agriculture livestock mining manu_industry construction transport trade household {
	gen `v'_fshare = (`v'_female / main_pop_total)
	gen `v'_fbaseline_share = `v'_fshare if (year == 1)
	replace `v'_fbaseline_share = `v'_fbaseline_share[_n-1] if missing(`v'_fbaseline_share)
}

gen other_service_fshare = other_service_female / main_pop_total
gen other_service_mshare = other_service_male / main_pop_total


label var cultivator_fshare "Number of female workers as cultivators in region/total number of workers in region"
label var cultivator_fbaseline_share "Number of initital female workers as cultivators in region/total number of initial workers in region"


* Male
foreach v in cultivator agriculture livestock mining manu_industry construction transport trade household {
	gen `v'_mshare = (`v'_male / main_pop_total)
	gen `v'_mbaseline_share = `v'_mshare if (year == 1)
	replace `v'_mbaseline_share = `v'_mbaseline_share[_n-1] if missing(`v'_mbaseline_share)
}

label var cultivator_mshare "Number of male workers as cultivators in region/total number of workers in region"
label var cultivator_mbaseline_share "Number of initial male workers as cultivators in region/total number of initial workers in region "

// Shift_share treatment and instrument 

* Female 
bys district_breakdown: gen fshift_share_treat = ///
	cultivator_tariff * cultivator_fshare + ///
	agriculture_tariff * agriculture_fshare + ///
	livestock_tariff * livestock_fshare + ///
	mining_tariff * mining_fshare + ///
	manufacturing_tariff * manu_industry_fshare + ///
	construction_tariff * construction_fshare + ///
	transport_tariff * transport_fshare + ///
	wholesale_trade_tariff * trade_fshare + ///
	housing_manu_tariff * household_fshare 
	
bys district_breakdown: gen fshift_share_instr = ///
	cultivator_1997_tariff * cultivator_fbaseline_share + ///
	agriculture_1997_tariff * agriculture_fbaseline_share + ///
    livestock_1997_tariff * livestock_fbaseline_share + ///
	mining_1997_tariff * mining_fbaseline_share + ///
	manufacturing_1997_tariff * manu_industry_fbaseline_share + ///
	construction_1997_tariff * construction_fbaseline_share + ///
	transport_1997_tariff * transport_fbaseline_share + ///
	wholesale_trade_1997_tariff * trade_fbaseline_share + ///
	housing_manu_1997_tariff * household_fbaseline_share		
	
	
* Male
bys district_breakdown: gen mshift_share_treat = ///
	cultivator_tariff * cultivator_mshare + ///
	agriculture_tariff * agriculture_mshare + ///
	livestock_tariff * livestock_mshare + ///
	mining_tariff * mining_mshare + ///
	manufacturing_tariff * manu_industry_mshare + ///
	construction_tariff * construction_mshare + ///
	transport_tariff * transport_mshare + ///
	wholesale_trade_tariff * trade_mshare + ///
	housing_manu_tariff * household_mshare

bys district_breakdown: gen mshift_share_instr = ///
	cultivator_1997_tariff * cultivator_mbaseline_share + ///
	agriculture_1997_tariff * agriculture_mbaseline_share + ///
    livestock_1997_tariff * livestock_mbaseline_share + ///
	mining_1997_tariff * mining_mbaseline_share + ///
	manufacturing_1997_tariff * manu_industry_mbaseline_share + ///
	construction_1997_tariff * construction_mbaseline_share + ///
	transport_1997_tariff * transport_mbaseline_share + ///
	wholesale_trade_1997_tariff * trade_mbaseline_share + ///
	housing_manu_1997_tariff * household_mbaseline_share	

	
* Need to control for time trend of baseline shares - similar to main spec

* Female - other services omitted 
gen sum_fbaseline_shares = cultivator_fbaseline_share + agriculture_fbaseline_share + livestock_fbaseline_share + mining_fbaseline_share + manu_industry_fbaseline_share + construction_fbaseline_share + transport_fbaseline_share + trade_fbaseline_share + household_fbaseline_share	

gen sum_fshare_period = sum_fbaseline_shares * period_2 

label var sum_fshare_period "Interaction of sum of female baseline shares with time period 2 dummy indicator"


* Male	
gen sum_mbaseline_shares = cultivator_mbaseline_share + agriculture_mbaseline_share + livestock_mbaseline_share + mining_mbaseline_share + manu_industry_mbaseline_share + construction_mbaseline_share + transport_mbaseline_share + trade_mbaseline_share + household_mbaseline_share	

gen sum_mshare_period = sum_mbaseline_shares * period_2 

label var sum_share_period "Interaction of sum of male baseline shares with time period 2 dummy indicator"	
	
	
* Getting rid of merge var	
drop _merge 	


**********

* Generating married women shares
gen married_wshare1519 = (married_women1519 / female_pop1519)
gen married_wshare2024 = (married_women2024 / female_pop2024)
gen married_wshare2529 = (married_women2529 / female_pop2529)
gen married_wshare3034 = (married_women3034 / female_pop3034)
gen married_wshareall = (married_womenall / female_popall)
	
* Generating log number	
gen ln_married_women1519 = log(married_women1519)
gen ln_female_pop1519 = log(female_pop1519)	

gen ln_female_pop2024 = log(female_pop2024)
gen ln_female_pop2529 = log(female_pop2529)	
	
	
* Generating fertility shares - so the share of women in that age group who had a child in the past year (treating no. of births in that age group as proxy for number of women in that age group who gave birth)
gen birth_share1519 = (births_last_year1519 / female_pop1519)
label var birth_share1519 "Share of women aged 15-19 who gave birth in the past year"

gen birth_share2024 = (births_last_year2024 / female_pop2024)
label var birth_share2024 "Share of women aged 20-24 who gave birth in the past year"

gen birth_share2529 = (births_last_year2529 / female_pop2529)
label var birth_share2529 "Share of women aged 25-29 who gave birth in the past year" 

gen birth_share3034 = (births_last_year3034 / female_pop3034)
label var birth_share3034 "Share of women aged 30-34 who gave birth in the past year"

gen birth_shareall = (births_last_yearall / female_popall)
label var birth_shareall "Share of all women who gave birth in the past year"

* Generating log of number of births
gen ln_births_last_year1519 = log(births_last_year1519)
gen ln_births_last_year2024 = log(births_last_year2024)
gen ln_births_last_year2529 = log(births_last_year2529)
gen ln_births_last_year3034 = log(births_last_year3034)
 			
			
***
* Generating variables for rescaling coefficients

gen shift_share_treat10 = shift_share_treat / 10
gen shift_share_instr10 = shift_share_instr / 10
gen fshift_share_treat10 = fshift_share_treat / 10
gen fshift_share_instr10 = fshift_share_instr / 10
gen mshift_share_treat10 = mshift_share_treat / 10
gen mshift_share_instr10 = mshift_share_instr / 10			
			
			
***
* Generating discounted total population, and employment measure (discounting dependents and retirees)

sort district_name rural year education_category					

* Labelling			
label var non_worker_discount "Sum of non-workers classified as dependents and pensioners"	

* Gender specific 
gen nw_female_discount = dependents_female + retired_female
gen nw_male_discount = dependents_male + retired_male 

gen total_pop_discounted = total_pop - non_worker_discount
gen female_pop_discounted = pop_female - nw_female_discount
gen male_pop_discounted = pop_male - nw_male_discount

* Employment measures 
gen employment_disc = main_pop_total / total_pop_discounted
gen female_employment_disc = main_pop_female / female_pop_discounted
gen male_employment_disc = main_pop_male / male_pop_discounted
			
			
gen log_pop_discounted = log(total_pop_discounted)
gen log_fpop_discounted = log(female_pop_discounted)
gen log_mpop_discounted = log(male_pop_discounted)
						
			
label var total_migrants2 "Total migrants from another district within state"
label var total_migrants4 "Total migrants from another state"			
			
***
save "$working_data/panel_states.dta", replace


**********


* Right now, only have migrant data for overall state - i.e. if state code = 00. I want all districts within the state to have the same migrant counts 


use "$working_data/panel_states.dta", clear 

gen interstate_migr_totalshare = total_migrants2 / total_pop
gen intrastate_migr_totalshare = total_migrants4 / total_pop 

local var_migr total_migrants2 total_migrants4 total_migrants_male2 total_migrants_male4 total_migrants_female2 total_migrants_female4 migr_employment_total2 migr_employment_total4 migr_employment_male2 migr_employment_male4 migr_employment_female2 migr_employment_female4 migr_marriage_total2 migr_marriage_total4 migr_marriage_male2 migr_marriage_male4 migr_marriage_female2 migr_marriage_female4 interstate_migr_totalshare intrastate_migr_totalshare

foreach var in `var_migr' {
	sort state_code	
	by state_code: egen max_`var' = max(`var')
	replace `var' = max_`var' if (year == 2 & rural == "Urban")
	replace `var' = 0 if (year == 1)
	drop max_`var'
}


* Now generating migrant controls vars
gen interstate_migr_control = interstate_migr_totalshare * period_2
gen intrastate_migr_control = intrastate_migr_totalshare * period_2


sort state_code district_code rural 

save "$working_data/panel_states.dta", replace




*** End of cleaning code ***

********************************************************************************	
********************************************************************************	
	
* Graph for education share of workforce by industry - in Appendix
	
preserve
	
keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")		
	
keep if rural == "Urban"
	
drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year
	

* Industry_total tells you how many people in each industry with that education level in that region working there. Industry_share will tell what proportion of workers of that education level in that region are working there

* Instead, proportion of workers out of all in that and industry who have that education level
	
collapse (mean) other_service_total other_service_share cultivators_total cultivator_share agriculture_total agriculture_share livestock_total livestock_share mining_total mining_share manu_industry_total manu_industry_share construction_total construction_share transport_total transport_share trade_total trade_share household_total household_share, by(education_category year)
	
drop *_share	



* Need to reshape the dataset for ease of plotting - have industries as rows and number of workers by education group as columns
rename (other_service_total cultivators_total agriculture_total livestock_total mining_total manu_industry_total construction_total transport_total trade_total household_total) (d1 d2 d3 d4 d5 d6 d7 d8 d9 d10)

label define indlab 1 "other_service" 2 "cultivator" 3 "agriculture" 4 "livestock" 5 "mining" 6 "manu_industry" 7 "construction" 8 "transport" 9 "trade" 10 "household"
label values d1-d10 indlab

reshape long d, i(education_category year) j(indnum)

decode indnum, gen(industry)

reshape wide d, i(industry year) j(education_category)

drop indnum

encode industry, gen(industry_num)
label define industry_num_lbl 1 "other_service" 2 "cultivator" 3 "agriculture" 4 "livestock" 5 "mining" 6 "manu_industry" 7 "construction" 8 "transport" 9 "trade" 10 "household"
label values industry_num industry_num_lbl

drop industry

label values d1 d2 d3 d4 d5
label values d5

rename d1 illiterate
rename d2 lit_below_matric
rename d3 matric_secondary
rename d4 graduate
rename d5 total 

keep if (year == 1)

gen illiterate_share = illiterate / total
gen lit_below_matric_share = lit_below_matric / total
gen matric_secondary_share = matric_secondary / total
gen graduate_share = graduate / total


* Graph
graph hbar illiterate_share lit_below_matric_share matric_secondary_share graduate_share, ///
    over (industry_num) ///
    stack asyvars ///
    percentage ///
	ytitle("Mean percentage of workers in each education group") ///
    graphregion(color(white))
	
restore	
	




