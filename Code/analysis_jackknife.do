/*******************************************************************************

* Title: analysis_jackknife

* Description: As a robustness check, iteratively leaving out one industry group and estimating regressions using remaining industry groups.

* Date: March 2025
* Author: Mahima Sabberwal

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


// JACKKNIFE RESAMPLING - LEAVE-ONE-OUT CONSTRUCTION OF THE SHIFTS

use "$working_data/panel_states.dta", clear


* I want to iteratively leave out one industry group from the treatment/instrument, and estimate the regression using the remaining industry groups - to see if any one particular industry is driving my results.


* Same sample restrictions 
keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

keep if (education_category == 5)
keep if (rural == "Urban") 

drop if missing(employment) | (employment == 0)
drop if missing(married_wshare1519)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year


* Renaming tariff industry category so that can use loop
rename manufacturing_tariff manu_industry_tariff
rename manufacturing_1997_tariff manu_industry_1997_tariff
rename housing_manu_tariff household_tariff
rename housing_manu_1997_tariff household_1997_tariff
rename wholesale_trade_tariff trade_tariff 
rename wholesale_trade_1997_tariff trade_1997_tariff


* Running regressions on each 'left-one-out industry group' in a loop - first generating necessary variables (see construction of treatment and instrument)
foreach v in cultivator agriculture livestock mining manu_industry construction transport trade household {
	gen ss_treat_min`v' = shift_share_treat - (`v'_tariff * `v'_share)
	gen ss_instr_min`v' = shift_share_instr - (`v'_1997_tariff * `v'_baseline_share)
	gen ss10_treat_min`v' = ss_treat_min`v' / 10
	gen ss10_instr_min`v' = ss_instr_min`v' / 10
	
	gen sum_baseshare_min`v' = (sum_baseline_shares - `v'_baseline_share)
	gen sum_shperiod_min`v' = sum_baseshare_min`v' * period_2
		
	* Gender specific shares
	gen fss_treat_min`v' = fshift_share_treat - (`v'_tariff * `v'_fshare)
	gen fss_instr_min`v' = fshift_share_instr - (`v'_1997_tariff * `v'_fbaseline_share)
	gen sum_fbaseshare_min`v' = (sum_fbaseline_shares - `v'_fbaseline_share)
	gen sum_fshperiod_min`v' = (sum_fbaseshare_min`v' * period_2)
	gen fss10_treat_min`v' = fss_treat_min`v' / 10
	gen fss10_instr_min`v' = fss_instr_min`v' / 10
	
	gen `v'_sharefemale = `v'_female / main_pop_female
	
	gen mss_treat_min`v' = mshift_share_treat - (`v'_tariff * `v'_mshare)
	gen mss_instr_min`v' = mshift_share_instr - (`v'_1997_tariff * `v'_mbaseline_share)
	gen sum_mbaseshare_min`v' = (sum_mbaseline_shares - `v'_mbaseline_share)
	gen sum_mshperiod_min`v' = (sum_mbaseshare_min`v' * period_2)
	gen mss10_treat_min`v' = mss_treat_min`v' / 10
	gen mss10_instr_min`v' = mss_instr_min`v' / 10
	
	gen `v'_sharemale = `v'_male / main_pop_male
	
	* Overall outcomes 	
	eststo all_employment`v': xtivreg employment_disc (ss10_treat_min`v' = ss10_instr_min`v') sum_shperiod_min`v', fe vce(cluster id_sd)
	
	eststo f_emp`v': xtivreg female_employment_disc (ss10_treat_min`v' = ss10_instr_min`v') sum_shperiod_min`v', fe vce(cluster id_sd)

	eststo m_emp`v': xtivreg male_employment_disc (ss10_treat_min`v' = ss10_instr_min`v') sum_shperiod_min`v', fe vce(cluster id_sd)
	
	eststo marrg1519_`v': xtivreg married_wshare1519 (ss10_treat_min`v' = ss10_instr_min`v') sum_shperiod_min`v', fe vce(cluster id_sd)

	eststo birth2024_`v': xtivreg birth_share2024 (ss10_treat_min`v' = ss10_instr_min`v') sum_shperiod_min`v', fe vce(cluster id_sd)	
	
	
	* Gender specific outcomes
	eststo all_gemp`v': xtivreg employment_disc (fss10_treat_min`v' mss10_treat_min`v' = fss10_instr_min`v' mss10_instr_min`v') sum_fshperiod_min`v' sum_mshperiod_min`v', fe vce(cluster id_sd)

	eststo all_gfemp`v': xtivreg female_employment_disc (fss10_treat_min`v' mss10_treat_min`v' = fss10_instr_min`v' mss10_instr_min`v') sum_fshperiod_min`v' sum_mshperiod_min`v', fe vce(cluster id_sd)
	
	eststo all_gmemp`v': xtivreg male_employment_disc (fss10_treat_min`v' mss10_treat_min`v' = fss10_instr_min`v' mss10_instr_min`v') sum_fshperiod_min`v' sum_mshperiod_min`v', fe vce(cluster id_sd)
	
	eststo gmarrg1519_`v': xtivreg married_wshare1519 (fss10_treat_min`v' mss10_treat_min`v' = fss10_instr_min`v' mss10_instr_min`v') sum_fshperiod_min`v' sum_mshperiod_min`v', fe vce(cluster id_sd)
	
	eststo gbirth2024_`v': xtivreg birth_share2024 (fss10_treat_min`v' mss10_treat_min`v' = fss10_instr_min`v' mss10_instr_min`v') sum_fshperiod_min`v' sum_mshperiod_min`v', fe vce(cluster id_sd)
	
}



* Checking first stage result when leaving out wholesale, retail and trade: - given the tariffs, expect this to be a stronger first stage. 

* Actually weaker, but this appears to be the case for any industry group --> could be due to variation
areg ss_treat_mintrade ss_instr_mintrade sum_shperiod_mintrade i.year, a(district_name) vce(cluster id_sd)

areg shift_share_treat shift_share_instr sum_share_period i.year, a(district_name) vce(cluster id_sd)



*********
// Coefficient plots of results

* Employment coefplot
coefplot ///
    (all_employmentcultivator, label("Cultivator") fcolor(erose) lcolor(erose)) ///
    (all_employmentagriculture, label("Agriculture")) ///
    (all_employmentlivestock, label("Livestock")) ///
    (all_employmentmining, label("Mining")) ///
    (all_employmentmanu_industry, label("Manufacturing") fcolor(ltblue) lcolor(ltblue)) ///
    (all_employmentconstruction, label("Construction")) ///
    (all_employmenttransport, label("Transport")) ///
    (all_employmenttrade, label("Wholesale, Retail and Trade") fcolor(stone) lcolor(stone)) ///
    (all_employmenthousehold, label("Household manuf") fcolor(lavender) lcolor(lavender)), ///
    coeflabel( ///
        ss10_treat_mincultivator = "Cultivator" ///
        ss10_treat_minagriculture = "Agriculture" ///
        ss10_treat_minlivestock = "Livestock" ///
        ss10_treat_minmining = "Mining" ///
        ss10_treat_minmanu_industry = "Manufacturing" ///
        ss10_treat_minconstruction = "Construction" ///
        ss10_treat_mintransport = "Transport" ///
        ss10_treat_mintrade = "Wholesale, trade" ///
        ss10_treat_minhousehold = "Household manuf") ///
    keep(ss10_treat_mincultivator ss10_treat_minagriculture ss10_treat_minlivestock ///
         ss10_treat_minmining ss10_treat_minmanu_industry ss10_treat_minconstruction ///
         ss10_treat_mintransport ss10_treat_mintrade ss10_treat_minhousehold) ///
    drop(sum_shperiod_*) ///
    vertical ///  
    xlabel(, angle(45)) ///
    recast(bar) barwidth(0.25) lwidth(thin) ///
    citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
	ytitle("Coefficient estimate") ///
    graphregion(color(white)) legend(off)	

graph export "$output/Prelim output/loo_industry_employment_coefp.jpg", replace


* Female employment coefplot 
coefplot ///
    (f_empcultivator, label("Cultivator") fcolor(erose) lcolor(erose)) ///
    (f_empagriculture, label("Agriculture")) ///
    (f_emplivestock, label("Livestock")) ///
    (f_empmining, label("Mining")) ///
    (f_empmanu_industry, label("Manufacturing") fcolor(ltblue) lcolor(ltblue)) ///
    (f_empconstruction, label("Construction")) ///
    (f_emptransport, label("Transport")) ///
    (f_emptrade, label("Wholesale, Retail and Trade") fcolor(stone) lcolor(stone)) ///
    (f_emphousehold, label("Household manuf") fcolor(lavender) lcolor(lavender)), ///
    coeflabel( ///
        ss10_treat_mincultivator = "Cultivator" ///
        ss10_treat_minagriculture = "Agriculture" ///
        ss10_treat_minlivestock = "Livestock" ///
        ss10_treat_minmining = "Mining" ///
        ss10_treat_minmanu_industry = "Manufacturing" ///
        ss10_treat_minconstruction = "Construction" ///
        ss10_treat_mintransport = "Transport" ///
        ss10_treat_mintrade = "Wholesale, trade" ///
        ss10_treat_minhousehold = "Household manuf") ///
    keep(ss10_treat_mincultivator ss10_treat_minagriculture ss10_treat_minlivestock ///
         ss10_treat_minmining ss10_treat_minmanu_industry ss10_treat_minconstruction ///
         ss10_treat_mintransport ss10_treat_mintrade ss10_treat_minhousehold) ///
    drop(sum_shperiod_*) ///
    vertical ///  
    xlabel(, angle(45)) ///
    recast(bar) barwidth(0.25) lwidth(thin) ///
    citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
	addplot(function y=0.017, range(-0.5 9.5) lpattern(dash) lcolor(gs10)) ///
	ytitle("Coefficient estimate") ///
    graphregion(color(white)) legend(off)	
	
graph export "$output/Prelim output/loo_industry_femployment_coefp.jpg", replace	


* Male employment coefplot 
coefplot ///
    (m_empcultivator, label("Cultivator") fcolor(erose) lcolor(erose)) ///
    (m_empagriculture, label("Agriculture")) ///
    (m_emplivestock, label("Livestock")) ///
    (m_empmining, label("Mining")) ///
    (m_empmanu_industry, label("Manufacturing") fcolor(ltblue) lcolor(ltblue)) ///
    (m_empconstruction, label("Construction")) ///
    (m_emptransport, label("Transport")) ///
    (m_emptrade, label("Wholesale, Retail and Trade") fcolor(stone) lcolor(stone)) ///
    (m_emphousehold, label("Household manuf") fcolor(lavender) lcolor(lavender)), ///
    coeflabel( ///
        ss10_treat_mincultivator = "Cultivator" ///
        ss10_treat_minagriculture = "Agriculture" ///
        ss10_treat_minlivestock = "Livestock" ///
        ss10_treat_minmining = "Mining" ///
        ss10_treat_minmanu_industry = "Manufacturing" ///
        ss10_treat_minconstruction = "Construction" ///
        ss10_treat_mintransport = "Transport" ///
        ss10_treat_mintrade = "Wholesale, trade" ///
        ss10_treat_minhousehold = "Household manuf") ///
    keep(ss10_treat_mincultivator ss10_treat_minagriculture ss10_treat_minlivestock ///
         ss10_treat_minmining ss10_treat_minmanu_industry ss10_treat_minconstruction ///
         ss10_treat_mintransport ss10_treat_mintrade ss10_treat_minhousehold) ///
    drop(sum_shperiod_*) ///
    vertical ///  
    xlabel(, angle(45)) ///
    recast(bar) barwidth(0.25) lwidth(thin) ///
    citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
	addplot(function y=-0.007, range(-0.5 9.5) lpattern(dash) lcolor(gs10)) ///
	ytitle("Coefficient estimate") ///
    graphregion(color(white)) legend(off)	

graph export "$output/Prelim output/loo_industry_memployment_coefp.jpg", replace	


* Marriage share coefplot
coefplot marrg1519_cultivator marrg1519_agriculture marrg1519_livestock marrg1519_mining marrg1519_manu_industry marrg1519_construction marrg1519_transport marrg1519_trade marrg1519_household, ///
    keep(ss10_treat_mincultivator ss10_treat_minagriculture ss10_treat_minlivestock ss10_treat_minmining ss10_treat_minmanu_industry ss10_treat_minconstruction ss10_treat_mintransport ss10_treat_mintrade ss10_treat_minhousehold) ///
    drop(sum_shperiod_*) ///
    graphregion(color(white)) xline(0) ///
    yscale(alt) ///
    coeflabel(shift_share_treat = "Shift-Share Treatment")

graph export "$output/Prelim output/loo_marriage_coefp.jpg", replace	


* Fertility coefplot
coefplot birth2024_cultivator birth2024_agriculture birth2024_livestock birth2024_mining birth2024_manu_industry birth2024_construction birth2024_transport birth2024_trade birth2024_household, ///
    keep(ss10_treat_mincultivator ss10_treat_minagriculture ss10_treat_minlivestock ss10_treat_minmining ss10_treat_minmanu_industry ss10_treat_minconstruction ss10_treat_mintransport ss10_treat_mintrade ss10_treat_minhousehold) ///
    drop(sum_shperiod_*) ///
    graphregion(color(white)) xline(0) ///
    yscale(alt) ///
    coeflabel(shift_share_treat = "Shift-Share Treatment")

graph export "$output/Prelim output/loo_fertility_coefp.jpg", replace	


*********
// Coefficient plots: gender-specific shock 

* All employment 
coefplot ///
    (all_gempcultivator, label("Cultivator") fcolor(erose) lcolor(erose)) ///
    (all_gempagriculture, label("Agriculture")) ///
    (all_gemplivestock,   label("Livestock")) ///
    (all_gempmining,      label("Mining")) ///
    (all_gempmanu_industry, label("Manufacturing") fcolor(ltblue) lcolor(ltblue)) ///
    (all_gempconstruction, label("Construction")) ///
    (all_gemptransport,   label("Transport")) ///
    (all_gemptrade,       label("Trade") fcolor(stone) lcolor(stone)) ///
    (all_gemphousehold,   label("Household manufacturing") fcolor(lavender) lcolor(lavender)), ///
    keep(fss10_treat_* mss10_treat_*) drop(sum_fshperiod_* sum_mshperiod_*) ///
    vertical ///  
    recast(bar) barwidth(0.25) lwidth(thin) ///
    citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    graphregion(color(white)) ///
	ytitle("Coefficient estimate") ///
	title("Employment")
	xlabel(1 "F" 2 "M" 3 " " 4 " " 5 " " 6 " " 7 " " 8 " " 9 " " 10 " " 11 " " 12 " " 13 " " 14 " " 15 " " 16 " " 17 " " 18 " ")
 
graph export "$output/Prelim output/loo_gemp_coefp.jpg", replace	
	
	
	
* Female employment
coefplot ///
    (all_gfempcultivator, label("Cultivator") fcolor(erose) lcolor(erose)) ///
    (all_gfempagriculture, label("Agriculture")) ///
    (all_gfemplivestock,   label("Livestock")) ///
    (all_gfempmining,      label("Mining")) ///
    (all_gfempmanu_industry, label("Manufacturing") fcolor(ltblue) lcolor(ltblue)) ///
    (all_gfempconstruction, label("Construction")) ///
    (all_gfemptransport,   label("Transport")) ///
    (all_gfemptrade,       label("Trade") fcolor(stone) lcolor(stone)) ///
    (all_gfemphousehold,   label("Household manufacturing") fcolor(lavender) lcolor(lavender)), ///
    keep(fss10_treat_* mss10_treat_*) drop(sum_fshperiod_* sum_mshperiod_*) ///
	vertical ///  
    recast(bar) barwidth(0.25) lwidth(thin) ///
    citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    graphregion(color(white)) ///
	ytitle("Coefficient estimate") ///
	title("Female employment")
	xlabel(1 "F" 2 "M" 3 " " 4 " " 5 " " 6 " " 7 " " 8 " " 9 " " 10 " " 11 " " 12 " " 13 " " 14 " " 15 " " 16 " " 17 " " 18 " ")
 
graph export "$output/Prelim output/loo_gfemp_coefp.jpg", replace	


* Male employment
coefplot ///
    (all_gmempcultivator, label("Cultivator") fcolor(erose) lcolor(erose)) ///
    (all_gmempagriculture, label("Agriculture")) ///
    (all_gmemplivestock,   label("Livestock")) ///
    (all_gmempmining,      label("Mining")) ///
    (all_gmempmanu_industry, label("Manufacturing") fcolor(ltblue) lcolor(ltblue)) ///
    (all_gmempconstruction, label("Construction")) ///
    (all_gmemptransport,   label("Transport")) ///
    (all_gmemptrade,       label("Trade") fcolor(stone) lcolor(stone)) ///
    (all_gmemphousehold,   label("Household manufacturing") fcolor(lavender) lcolor(lavender)), ///
    keep(fss10_treat_* mss10_treat_*) ///
    drop(sum_fshperiod_* sum_mshperiod_*) ///
	vertical ///  
    recast(bar) barwidth(0.25) lwidth(thin) ///
    citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    graphregion(color(white)) ///
	ytitle("Coefficient estimate") ///
    title("Male employment") ///
	xlabel(1 "F" 2 "M" 3 " " 4 " " 5 " " 6 " " 7 " " 8 " " 9 " " 10 " " 11 " " 12 " " 13 " " 14 " " 15 " " 16 " " 17 " " 18 " ")
 
graph export "$output/Prelim output/loo_gmemp_coefp.jpg", replace	


* Marriage
coefplot ///
    (gmarrg1519_cultivator, label("Cultivator")) ///
    (gmarrg1519_agriculture, label("Agriculture")) ///
    (gmarrg1519_livestock,   label("Livestock")) ///
    (gmarrg1519_mining,      label("Mining")) ///
    (gmarrg1519_manu_industry, label("Manufacturing")) ///
    (gmarrg1519_construction, label("Construction")) ///
    (gmarrg1519_transport,   label("Transport")) ///
    (gmarrg1519_trade,       label("Trade")) ///
    (gmarrg1519_household,   label("Household manufacturing")), ///
    keep(fss10_treat_* mss10_treat_*) ///
    drop(sum_fshperiod_* sum_mshperiod_*) ///
    vertical ///
    yline(0, lcolor(black) lpattern(dash)) ///
    legend(on) ///
    title("Marriage share, 15 - 19") ///
	xlabel(1 "F" 2 "M" 3 " " 4 " " 5 " " 6 " " 7 " " 8 " " 9 " " 10 " " 11 " " 12 " " 13 " " 14 " " 15 " " 16 " " 17 " " 18 " ")
 
graph export "$output/Prelim output/loo_marriage_coefp.jpg", replace	


* Fertility 
coefplot ///
    (gbirth2024_cultivator, label("Cultivator")) ///
    (gbirth2024_agriculture, label("Agriculture")) ///
    (gbirth2024_livestock,   label("Livestock")) ///
    (gbirth2024_mining,      label("Mining")) ///
    (gbirth2024_manu_industry, label("Manufacturing")) ///
    (gbirth2024_construction, label("Construction")) ///
    (gbirth2024_transport,   label("Transport")) ///
    (gbirth2024_trade,       label("Trade")) ///
    (gbirth2024_household,   label("Household manufacturing")), ///
    keep(fss10_treat_* mss10_treat_*) ///
    drop(sum_fshperiod_* sum_mshperiod_*) ///
    vertical ///
    yline(0, lcolor(black) lpattern(dash)) ///
    legend(on) ///
    title("Fertility share, 20 - 24") ///
	xlabel(1 "F" 2 "M" 3 " " 4 " " 5 " " 6 " " 7 " " 8 " " 9 " " 10 " " 11 " " 12 " " 13 " " 14 " " 15 " " 16 " " 17 " " 18 " ")
 
graph export "$output/Prelim output/loo_fertility_coefp.jpg", replace





