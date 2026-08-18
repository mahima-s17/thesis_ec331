/*******************************************************************************
* Title: Master

* Author: Mahima Sabberwal
* Date: April 2025
 
* Description: Master do file for undergraduate thesis work. Clean do file merges district-level datasets, add tariffs data, and constructs composite regions. Analysis do-files for Shift-Share IV estimates.
 
*******************************************************************************/

clear all
macro drop _all
set more off, perm


* Filepath globals
global thesis_project "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis"

global csv_1991 "$thesis_project\Data\1991"
global csv_2001 "$thesis_project\Data\2001"
global working_data "$thesis_project\Clean data"
global output "$thesis_project\Output"
global code "$thesis_project\Code"
global subs_data "$thesis_project\Data"
global working_data "$thesis_project\Clean data"


*** Running project programs *** 

* Cleaning and merging together required datasets, and constructing composite regions to construct panel dataset for analysis
do "$code\clean_do"

* Analysis:
do "$code\analysis_do" // Main SSIV analysis
do "$code\analysis_jackknife" // Leave-One-Out shift estimates
do "$code\analysis_ssaggregate" // ssaggregate package transforming the dataset

do "$code\robustness_checks_banks" // robustness check for pre-trends on number of banks in a region















