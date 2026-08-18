/*******************************************************************************

* Title: map_rendering

* Date: March 2025
* Author: Mahima Sabberwal

*******************************************************************************/

clear all
set more off, perm

ssc install shp2dta
ssc install spmap


* Globals
global working_data "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Clean data"
global output "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Output"
global subs_data "C:\Users\mahim\OneDrive\Documents\3rd Year\EC331 - Thesis\Data"


**********

* Merging keys 

/* 1. open the SHRUG PCA */
use pc01_pca_shrid.dta, clear

/* 2. prefix shrug data so it does not duplicate */
ren * sh_*
ren sh_shrid shrid

/* 3. merge to the additional population census data */
merge 1:1 shrid using PCA2001.dta, keepusing(...)

/* 4. collapse PCA back to the shrid level, but don't recollapse SHRUG data */
collapse (sum) pc01_pca_* (firstnm) sh_*, by(shrid)

/* 5. reset names to original format */
ren sh_* *

/* 5. Go back to step 2 in order to merge to additional data */
ren * sh_*
ren sh_shrid shrid
merge 1:1 shrid using PCA1991.dta
[etc...]








shp2dta using "$subs_data/shrid2_open.shp", ///
    database("$subs_data/shrid2_open_db.dta") ///
	coordinates("$subs_data/shrid2_open_coord.dta") ///
    genid(id)

* Merging to my database with data on treatment and instrument 
use "myshapefile_db.dta", clear
merge 1:m id using "treatment_data.dta"

















