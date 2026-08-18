/*******************************************************************************
* Title: analysis_do

* Author: Mahima Sabberwal
* Date: January 2025

* Description: Code for main analysis and regression results on final dataset panel_states (runs first stage and SSIV regressions).

*******************************************************************************/

clear all
set more off, perm

ssc install estout, replace 
ssc install coefplot, replace 
ssc install ssaggregate 


use "$working_data/panel_states.dta", clear


********************************************************************************
********************************************************************************
	
// Summary Statistics table:

preserve 

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

keep if (education == 5)
keep if (rural == "Urban") 

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year


estpost tabstat total_pop_discounted female_pop_discounted male_pop_discounted employment_disc female_employment_disc male_employment_disc married_wshare1519 birth_share2024 birth_share1519 shift_share_treat shift_share_instr mshift_share_treat mshift_share_instr fshift_share_treat fshift_share_instr cultivator_share agriculture_share manu_industry_share household_share mining_share construction_share trade_share transport_share other_service_share, statistics(mean sd) by(year)
	
restore 	
	
	
********************************************************************************	
********************************************************************************	
	
// First stages plots:

* Rule of thumb for sufficiently strong instrument: F-stat >= 10 (Stock and Yogo). More recently, 30 is a good standard in microeconomics

// Sample restriction for all analysis

* Want to exclude the aggregate state observations (which take district code 00), keeping observations where there is only one district (state = district):


preserve

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")
keep if (education == 5) // 'Total' education observation
keep if (rural == "Urban") // Instrument is weak for rural observations

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year 

// First stage for whole instrument, then gender-specific shocks

xtreg shift_share_treat shift_share_instr sum_share_period, fe vce(cluster id_sd)
predict shift_share_treathat, xb
test shift_share_instr = 0

keep if (year == 2) // only want to plot for 2001, since treatment and instrument identical for 1991

twoway ///
  (scatter shift_share_treat shift_share_treathat [fweight=total_pop], ///
  msymbol(circle_hollow)) ///
  (lfit   shift_share_treat shift_share_treathat [fweight=total_pop]), ///
  ytitle("Shift-share actual treatment") xtitle("Shift-share predicted treatment") ///
  legend(off)

graph export "$output/Prelim output/first_stage_overall.png", replace		   
	  
restore	   
 
  
// For male and female-specific shock instrument

* Male-specific
preserve

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")
keep if (education == 5)
keep if (rural == "Urban")

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year 

xtreg mshift_share_treat mshift_share_instr sum_mshare_period fshift_share_instr sum_fshare_period, fe vce(cluster id_sd)
predict mshift_share_treathat, xb
test mshift_share_instr = 0


* For female-specific shock instrument 
xtreg fshift_share_treat fshift_share_instr sum_fshare_period mshift_share_instr sum_mshare_period, fe vce(cluster id_sd)
predict fshift_share_treathat, xb
test fshift_share_instr = 0

keep if (year == 2)

twoway ///
  (scatter mshift_share_treat mshift_share_treathat [fweight=total_pop], ///
  msymbol(circle_hollow)) ///
  (lfit mshift_share_treat mshift_share_treathat [fweight=total_pop]), ///
  ytitle("Male-specifc SS actual treatment") xtitle("Male-specifc SS predicted treatment") ///
  legend(off)

graph export "$output/Prelim output/first_stage_male.png", replace		  
  
twoway ///
  (scatter fshift_share_treat fshift_share_treathat [fweight=total_pop], ///
  msymbol(circle_hollow)) ///
  (lfit fshift_share_treat fshift_share_treathat [fweight=total_pop]), ///
  ytitle("Female-specifc SS actual treatment") xtitle("Female-specifc SS predicted treatment") ///
  legend(off)  
  
graph export "$output/Prelim output/first_stage_female.png", replace		

restore 


********************************************************************************
  ****************************************************************************

// Overall outcomes - Table 1

* xtivreg specified with fe - fixed-effects using district_breakdown (equivalent to district name with sample restrictions) and year. Default for xtivreg is random effects estimator.

* On employment measure, discounting for number of dependents and retirees
* Three observations without employment values/employment = 0 - filler in census


// Employment 
preserve 

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

keep if (education == 5)
keep if (rural == "Urban") 

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_name_num year 

eststo all_employment: xtivreg employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period, fe first vce(cluster id_sd)
predict employment_dischat, xb
twoway (scatter employment_disc shift_share_treat10) ///
	   (lfit employment_dischat shift_share_treat10)
	   
eststo female_employment: xtivreg female_employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)
predict female_employment_dischat, xb
twoway (scatter female_employment_disc shift_share_treat10) ///
	   (lfit female_employment_dischat shift_share_treat10)

eststo male_employment: xtivreg male_employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)
predict male_employment_dischat, xb
twoway (scatter male_employment_disc shift_share_treat10) ///
	   (lfit male_employment_dischat shift_share_treat10)

restore


**********

// Marriage and fertility

preserve

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

* Totals:
keep if (rural == "Urban")
keep if (education_category == 5)

drop if missing(married_wshare1519)
drop if missing(shift_share_treat)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year


* Marriage
eststo mshare1519: xtivreg married_wshare1519 (shift_share_treat10 = shift_share_instr10) ///
sum_share_period, fe vce(cluster id_sd)

eststo mshare2024: xtivreg married_wshare2024 (shift_share_treat10 = shift_share_instr10) ///
sum_share_period, fe vce(cluster id_sd)

* Birth share
eststo birth_share2024: xtivreg birth_share2024 (shift_share_treat10 = shift_share_instr10) ///
sum_share_period, fe vce(cluster id_sd)	

restore

* Exporting all results to a coefficient plot
* Coefplot
coefplot ///
	(all_employment, label("Employment") fcolor(ltblue) lcolor(ltblue)) ///
	(female_employment, label("Female employment") fcolor(erose) lcolor(erose)) ///
	(male_employment, label("Male employment") fcolor(eltgreen) lcolor(eltgreen)) ///
	(mshare1519, label("Marriage, 15 - 19") fcolor(stone) lcolor(stone)) ///
    (mshare2024, label("Marriage, 20 - 24") fcolor(olive_teal) lcolor(olive_teal)) ///
	(birth_share2024, label("Fertility past year, 20 - 24") fcolor(lavender) lcolor(lavender)), ///
	keep(shift_share_treat10) drop(sum_share_period) ///
	vertical ///
	recast(bar) barwidth(0.1) lwidth(thin) ///
    citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    coeflabel(shift_share_treat10 = "Shift-Share Treatment") ///
	graphregion(color(white)) xline(0) 

graph export "$output/Prelim output/overallresults_coefplot.jpg", replace 


* Exporting results to regression table
esttab all_employment female_employment male_employment mshare1519 mshare2024 birth_share2024 using "$output/Prelim output/employment_urban.tex", replace ///
	keep(shift_share_treat10 sum_share_period) ///
    b(3) se(3) se booktabs nomtitles frag ///
	starlevels(* 0.10 ** 0.05 *** 0.01) 	

	

********************************************************************************
********************************************************************************

// Gender-specific shocks - Figures 4 and 5 


// Employment 
preserve 

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

* Totals:
keep if (rural == "Urban")
keep if (education_category == 5)

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_name_num year

eststo clear
* Overall employment
eststo all_gemployment: xtivreg employment_disc (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe first vce(cluster id_sd)

test _b[fshift_share_treat10] = _b[mshift_share_treat10]

* Female employment
eststo female_gemployment: xtivreg female_employment_disc (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

test _b[fshift_share_treat10] = _b[mshift_share_treat10]

* Male employment
eststo male_gemployment: xtivreg male_employment_disc (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

test _b[fshift_share_treat10] = _b[mshift_share_treat10]


restore

 
* Table 
esttab all_gemployment female_gemployment male_gemployment ///
	using "$output/Prelim output/gender_specific_employment_urban.tex", replace ///
	keep(fshift_share_treat10 mshift_share_treat10) ///
    b(3) se(3) se booktabs nomtitles frag ///
	starlevels(* 0.10 ** 0.05 *** 0.01) 	

	
* Coefplot
// All employment
coefplot all_gemployment, ///
    keep(fshift_share_treat10 mshift_share_treat10) ///
    drop(sum_share_period) ///
    vertical ///
    recast(bar) barwidth(0.25) fcolor(ltblue) lcolor(ltblue) lwidth(thin) ///
	citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    yline(0, lcolor(black) lpattern(dash)) ///
    coeflabel( ///
        fshift_share_treat10 = "Female SS" ///
        mshift_share_treat10 = "Male SS") ///
    legend(off) title("All Employment") name(gall, replace)	

// Female Employment
coefplot female_gemployment, ///
    keep(fshift_share_treat10 mshift_share_treat10) ///
    drop(sum_share_period) ///
    vertical ///
	recast(bar) barwidth(0.25) fcolor(ltblue) lcolor(ltblue) lwidth(thin) ///
	citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    yline(0, lcolor(black) lpattern(dash)) ///
    coeflabel( ///
        fshift_share_treat10 = "Female SS" ///
        mshift_share_treat10 = "Male SS") ///
    legend(off) title("Female Employment") name(gfemale, replace)
	
// Male Employment
coefplot male_gemployment, ///
    keep(fshift_share_treat10 mshift_share_treat10) ///
    drop(sum_share_period) ///
    vertical ///
	recast(bar) barwidth(0.25) fcolor(ltblue) lcolor(ltblue) lwidth(thin) ///
	citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    yline(0, lcolor(black) lpattern(dash)) ///
    coeflabel( ///
        fshift_share_treat10 = "Female SS" ///
        mshift_share_treat10 = "Male SS") ///
    legend(off) title("Male Employment") name(gmale, replace)
	

graph combine gall gfemale gmale, col(3) ycommon


graph export "$output/Prelim output/gender_specific_employmentdisc_urban_coefp.jpg", replace 



*****

* Estimating female-specific estimates without holding fixed male-specific exposure - robustness

eststo female_gemployment1: xtivreg female_employment_disc (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

eststo female_gemployment2: xtivreg female_employment_disc (fshift_share_treat10 = fshift_share_instr10) sum_fshare_period, fe vce(cluster id_sd)

eststo female_gemployment3: xtivreg female_employment_disc (fshift_share_treat10 = fshift_share_instr10) sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

esttab female_gemployment1 female_gemployment2 female_gemployment3 ///
	using "$output/Prelim output/gfemp_omitting.tex", replace ///
	keep(fshift_share_treat10 mshift_share_treat10 sum_fshare_period sum_mshare_period) ///
    b(3) se(3) se booktabs nomtitles frag ///
	starlevels(* 0.10 ** 0.05 *** 0.01) 	

**********


// Marriage and fertility

preserve

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

* Totals:
keep if (rural == "Urban")
keep if (education_category == 5)

drop if missing(married_wshare1519)
drop if missing(shift_share_treat)
bysort id_sd (year): drop if _N == 1
xtset district_name_num year


* Marriage gendered
eststo mshare1519_gendered: xtivreg married_wshare1519 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

eststo mshare2024_gendered: xtivreg married_wshare2024 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

* Birth share gendered
eststo birth_share2024_gendered: xtivreg birth_share2024 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

restore

* Coefplot
// Marriage
coefplot mshare1519_gendered, ///
    keep(fshift_share_treat10 mshift_share_treat10) ///
    drop(sum_share_period) ///
    vertical ///
	recast(bar) barwidth(0.25) fcolor(ltblue) lcolor(ltblue) lwidth(thin) ///
	citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    yline(0, lcolor(black) lpattern(dash)) ///
    coeflabel( ///
        fshift_share_treat10 = "Female SS" ///
        mshift_share_treat10 = "Male SS") ///
    legend(off) title("Share of women married, 15 - 19") name(gmarried_share1519, replace)

coefplot mshare2024_gendered, ///
    keep(fshift_share_treat10 mshift_share_treat10) ///
    drop(sum_share_period) ///
    vertical ///
	recast(bar) barwidth(0.25) fcolor(ltblue) lcolor(ltblue) lwidth(thin) ///
	citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    yline(0, lcolor(black) lpattern(dash)) ///
    coeflabel( ///
        fshift_share_treat10 = "Female SS" ///
        mshift_share_treat10 = "Male SS") ///
    legend(off) title("Share of women married, 20 - 24") name(gmarried_share2024, replace)	
	
// Fertility	
coefplot birth_share2024_gendered, ///
    keep(fshift_share_treat10 mshift_share_treat10) ///
    drop(sum_share_period) ///
    vertical ///
	recast(bar) barwidth(0.25) fcolor(ltblue) lcolor(ltblue) lwidth(thin) ///
	citop cirecast(rcap) ciopts(lcolor(emidblue)) ///
    yline(0, lcolor(black) lpattern(dash)) ///
    coeflabel( ///
        fshift_share_treat10 = "Female SS" ///
        mshift_share_treat10 = "Male SS") ///
    legend(off) title("Share gave birth past year, 20 - 24") name(gbirth_share, replace)
	
graph combine gmarried_share1519 gmarried_share2024 gbirth_share, col(3) ycommon	
	
graph export "$output/Prelim output/gendered_marriage_birth_coefp.jpg", replace
	
	
	
	
	
*** Robustness checks ***	
	
* Note: Leave-One-Out construction of the shifts (industry) analysis on a separate dofile: analysis_jackknife 
	
********************************************************************************
********************************************************************************

// Robustness checks: non-discounted employment marriage and fertility results for other age groups (overall and gender-specific):

eststo clear 


* Employment - overall
preserve 

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")
keep if (education == 5)
keep if (rural == "Urban") 

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_name_num year 

eststo allnd_employment: xtivreg employment (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd) 
eststo femalend_employment: xtivreg female_employment (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)
eststo malend_employment: xtivreg male_employment (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)


* Employment - gender-specific
eststo allnd_gemployment: xtivreg employment (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe first vce(cluster id_sd)

eststo malend_gemployment: xtivreg male_employment (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

eststo femalend_gemployment: xtivreg female_employment (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

restore


* Marriage 

gen birth_shareall = (births_last_yearall / female_popall)
label var birth_shareall "Share of all women who gave birth in the past year"

preserve 

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

keep if (rural == "Urban")
keep if (education_category == 5)

drop if missing(married_wshare1519)
drop if missing(shift_share_treat)
bysort id_sd (year): drop if _N == 1
xtset district_name_num year

eststo mshare1519: xtivreg married_wshare1519 (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)

eststo mshare2024: xtivreg married_wshare2024 (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)

eststo mshareall: xtivreg married_wshareall (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)

* Gendered 
eststo mshare1519_gendered: xtivreg married_wshare1519 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

eststo mshare2024_gendered: xtivreg married_wshare2024 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

eststo mshareall_gendered: xtivreg married_wshareall (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)


* Fertility	
eststo birth_share1519: xtivreg birth_share1519 (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)	
eststo birth_share2024: xtivreg birth_share2024 (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)	
eststo birth_shareall: xtivreg birth_shareall (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)		
	
* Birth share gendered
eststo birth_share1519_gendered: xtivreg birth_share1519 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

eststo birth_share2024_gendered: xtivreg birth_share2024 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

eststo birth_shareall_gendered: xtivreg birth_shareall (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)
	
restore 	


// Table for overall exposure
esttab ///
  allnd_employment femalend_employment malend_employment mshare1519 mshare2024 mshareall birth_share1519 birth_share2024 birth_shareall, ///
    keep(shift_share_treat10 sum_share_period) ///
    b(3) se(3) ///
    starlevels(* 0.10 ** 0.05 *** 0.01) ///
    nomtitles frag  


// Table for gendered exposure
esttab allnd_gemployment femalend_gemployment malend_gemployment mshare1519_gendered mshare2024_gendered mshareall_gendered birth_share1519_gendered birth_share2024_gendered birth_shareall_gendered, ///
	keep(fshift_share_treat10 mshift_share_treat10 sum_fshare_period sum_mshare_period) ///
    b(3) se(3) se booktabs nomtitles frag ///
	starlevels(* 0.10 ** 0.05 *** 0.01) 	
	
	
	
	
********************************************************************************
********************************************************************************


* Large regions robustness check - Appendix 

* Want to check analysis is robust to leaving out very large regions - that it isn't a few regions driving results.


preserve 

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

keep if (education == 5)
keep if (rural == "Urban") 

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year


* Dropping regions with population beyond the 90th percentile

keep if total_pop < 1324954 

* Overall exposure regressions
eststo emp_lr: xtivreg employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)

eststo femp_lr: xtivreg female_employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)

eststo memp_lr: xtivreg male_employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)

eststo marr1519_lr: xtivreg married_wshare1519 (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)
eststo marr2024_lr: xtivreg married_wshare2024 (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)
eststo birth2024_lr: xtivreg birth_share2024 (shift_share_treat10 = shift_share_instr10) sum_share_period, fe vce(cluster id_sd)

***

* Gender-specific regressions
eststo empgend_lr: xtivreg employment_disc ///
(fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

* Male employment
eststo mempgend_lr: xtivreg male_employment_disc (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

* Female employment
eststo fempgend_lr: xtivreg female_employment_disc ///
(fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)


eststo mshare1519_gendlr: xtivreg married_wshare1519 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

eststo mshare2024_gendlr: xtivreg married_wshare2024 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)

eststo birth2024_gendlr: xtivreg birth_share2024 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period, fe vce(cluster id_sd)


restore 


* Table 
esttab emp_lr femp_lr memp_lr marr1519_lr marr2024_lr birth2024_lr using "$output/Prelim output/large_regions_overall.tex", replace ///
	keep(shift_share_treat10 sum_share_period) ///
    b(3) se(3) se booktabs nomtitles frag ///
	starlevels(* 0.10 ** 0.05 *** 0.01) 	

esttab empgend_lr fempgend_lr mempgend_lr mshare1519_gendlr mshare2024_gendlr birth2024_gendlr using "$output/Prelim output/large_regions_gendered.tex", replace ///
	keep(fshift_share_treat10 mshift_share_treat10 sum_fshare_period sum_mshare_period) ///
    b(3) se(3) se booktabs nomtitles frag ///
	starlevels(* 0.10 ** 0.05 *** 0.01) 	
	



********************************************************************************
********************************************************************************

// Robustness check: Migration control

preserve 

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

keep if (education == 5)
keep if (rural == "Urban") 

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_name_num year 


eststo all_employment_migr: xtivreg employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period interstate_migr_control intrastate_migr_control, fe first vce(cluster id_sd)

eststo female_employment_migr: xtivreg female_employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)

eststo male_employment_migr: xtivreg male_employment_disc (shift_share_treat10 = shift_share_instr10) sum_share_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)

restore


**********

// Marriage and fertility

preserve

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

* Totals:
keep if (rural == "Urban")
keep if (education_category == 5)

drop if missing(married_wshare1519)
drop if missing(shift_share_treat)
bysort id_sd (year): drop if _N == 1
xtset district_breakdown year


* Marriage
eststo mshare1519_migr: xtivreg married_wshare1519 (shift_share_treat10 = shift_share_instr10) ///
sum_share_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)

eststo mshare2024_migr: xtivreg married_wshare2024 (shift_share_treat10 = shift_share_instr10) ///
sum_share_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)

* Birth share
eststo birth_share2024_migr: xtivreg birth_share2024 (shift_share_treat10 = shift_share_instr10) ///
sum_share_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)	

restore 


* Table 
esttab all_employment_migr female_employment_migr male_employment_migr mshare1519_migr mshare2024_migr birth_share2024_migr using "$output/Prelim output/migration_employment_urban.tex", replace ///
	keep(shift_share_treat10 sum_share_period interstate_migr_control intrastate_migr_control) ///
    b(3) se(3) se booktabs nomtitles frag ///
	starlevels(* 0.10 ** 0.05 *** 0.01) 	



********* Gender-specific 

preserve 

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

* Totals:
keep if (rural == "Urban")
keep if (education_category == 5)

drop if missing(employment) | (employment == 0)
bysort id_sd (year): drop if _N == 1
xtset district_name_num year

eststo clear
* Overall employment
eststo all_gemployment_migr: xtivreg employment_disc (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)


* Female employment
eststo female_gemployment_migr: xtivreg female_employment_disc (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)


* Male employment
eststo male_gemployment_migr: xtivreg male_employment_disc (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)

restore

*****
preserve

keep if (district_code != "00") | inlist(id_sd, "2800", "2900", "3000", "3100", "3200")

* Totals:
keep if (rural == "Urban")
keep if (education_category == 5)

drop if missing(married_wshare1519)
drop if missing(shift_share_treat)
bysort id_sd (year): drop if _N == 1
xtset district_name_num year


* Marriage gendered
eststo mshare1519_gendmigr: xtivreg married_wshare1519 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)

eststo mshare2024_gendmigr: xtivreg married_wshare2024 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)

* Birth share gendered
eststo birth_share2024_gendmigr: xtivreg birth_share2024 (fshift_share_treat10 mshift_share_treat10 = fshift_share_instr10 mshift_share_instr10) ///
sum_fshare_period sum_mshare_period interstate_migr_control intrastate_migr_control, fe vce(cluster id_sd)

restore



* Table 
esttab all_gemployment_migr female_gemployment_migr male_gemployment_migr mshare1519_gendmigr mshare2024_gendmigr birth_share2024_gendmigr ///
	using "$output/Prelim output/gender_specific_migration_employment_urban.tex", replace ///
	keep(fshift_share_treat10 mshift_share_treat10 interstate_migr_control intrastate_migr_control) ///
    b(3) se(3) se booktabs nomtitles frag ///
	starlevels(* 0.10 ** 0.05 *** 0.01) 	


	
	
	
	
	
	
	
	
	
