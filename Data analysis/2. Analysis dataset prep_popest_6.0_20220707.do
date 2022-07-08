*****************************************
* 2. Analysis dataset prep - population estimates
*****************************************
*For ref, pop estimates created during previous work
*Adapted for current paper

clear 

***************************************
*Create 3 dig icd 10 code lookup

import delimited "S:\ECHO_IHI_CPRD\Becky\Fatigue cancer risk\Codes\lookup_cancersite_fatigue_v5.txt", varnames(1) clear 

collapse (first) cancer_site_number cancer_site_desc cancer_site_number_50 cancer_site_desc_50, by(gender icd10_3dig)

*Save data
save "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\cancer_site_lookup_3dig_50.dta", replace


***************************************
*Open population cancer cases

import delimited "S:\ECHO_IHI_CPRD\Becky\Fatigue cancer risk\Population estimates\2011_cancercases_3dig_clean.csv", varnames(1) clear 

replace icd10_3digit = trim(icd10_3digit)

*Save data
save "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\Fatigue paper_popinc_20072020_a.dta", replace

*Merge in cancer site lookup
rename icd10_3digit icd10_3dig
merge m:1 gender icd10_3dig using "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\cancer_site_lookup_3dig_50.dta"

*Merge check: ensure all cancer sites with cases in population are matched to a cancer site group
assert _merge != 1

*Drop cancer sites not matched from cancer site lookup (which includes all possible combinations of gender and cancer site)
drop if _merge == 2
drop _merge

*Count by cancer site grouping
collapse (sum)age_30to34 age_35to39 age_40to44 age_45to49 age_50to54 age_55to59 age_60to64 age_65to69 age_70to74 age_75to79 age_80to84 age_85plus, by (cancer_site_number cancer_site_desc gender)

*Create cancers total by age
egen age_allages = rowtotal(age_30to34 age_35to39 age_40to44 age_45to49 age_50to54 age_55to59 age_60to64 age_65to69 age_70to74 age_75to79 age_80to84 age_85plus)

*Reshape data to long format
reshape long age_, i(gender cancer_site_number cancer_site_desc) j(age) string
rename age_ popest_2011_annual_cases

*Check: no missing cases
assert !missing(popest_2011_annual_cases)

*Reformat age var
gen agegroup = .
replace agegroup = 99 if age =="allages"
replace agegroup = 0 if age =="<30"
replace agegroup = 30 if age =="30to34"
replace agegroup = 35 if age =="35to39"
replace agegroup = 40 if age =="40to44"
replace agegroup = 45 if age =="45to49"
replace agegroup = 50 if age =="50to54"
replace agegroup = 55 if age =="55to59"
replace agegroup = 60 if age =="60to64"
replace agegroup = 65 if age =="65to69"
replace agegroup = 70 if age =="70to74"
replace agegroup = 75 if age =="75to79"
replace agegroup = 80 if age =="80to84"
replace agegroup = 85 if age =="85plus"

label define agegroup 99 "all_ages" 0 "<30" 30 "30-34" 35 "35-39" 40 "40-44" 45 "45-49" 50 "50-54" 55 "55-59" 60 "60-64" 65 "65-69" 70 "70-74" 75 "75-79" 80 "80-84" 85 "85+"

label values agegroup agegroup

drop age


***************************************
*Create total cancers
*NB: Run the following code all together

* Create cases for m+f combined, by age group & cancer site
preserve
collapse (sum) popest_2011_annual_cases, by(cancer_site_number cancer_site_desc agegroup)
gen gender = "Total"

tempfile d
save "`d'"
restore

append using "`d'"

*Create total cases for all cancers combined,  for each age group, for each gender
preserve
collapse (sum) popest_2011_annual_cases, by(agegroup gender)
gen cancer_site_desc = "All cancers"
gen cancer_site_number = 1

tempfile g
save "`g'"

restore

append using "`g'"

*Save data
save "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\Fatigue paper_popinc_20072020_b.dta", replace


***************************************
*Add population estimates mid-2011

import delimited "S:\ECHO_IHI_CPRD\Becky\Fatigue cancer risk\Population estimates\Mid-2011-unformatted-persons_clean.csv", clear

*Create age groups
egen agegroup = cut(age_cont), at(0,30,35,40,45,50,55,60,65,70,75,80,85,140)
drop if agegroup == .

*Drop under 30s
drop if agegroup == 0

* Create est total for all ages combined, by gender
preserve
collapse (sum) popest, by(gender)
gen agegroup = 99

tempfile d
save "`d'"
restore

append using "`d'"

save "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\Fatigue paper_popest_20072020_a.dta", replace

*Add up population size by age and gender
collapse (sum) popest, by (agegroup gender)

label define agegroup 99 "all_ages" 0 "<30" 30 "30-34" 35 "35-39" 40 "40-44" 45 "45-49" 50 "50-54" 55 "55-59" 60 "60-64" 65 "65-69" 70 "70-74" 75 "75-79" 80 "80-84" 85 "85+"

label values agegroup agegroup

save "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\Fatigue paper_popest_20072020_b.dta", replace


****************************************
*Join pop estimaes to pop incidence file

use "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\Fatigue paper_popinc_20072020_b.dta", clear

merge m:1 gender agegroup  using "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\Fatigue paper_popest_20072020_b.dta", 

*Check merge worked, all gender/ age categories matched with pop estimates
assert _merge == 3 

drop if agegroup == 0
drop _merge

save "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\Fatigue paper_popinc&est_20072020_b.dta", replace


*************************************************************
*Adapt pop estimates for this paper

use "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\Fatigue paper_popinc&est_20072020_b.dta", clear
rename popest_2011_annual_cases cases_12mo
rename popest denominator

*Create 9 month cancer risk %s
gen cases_9mo = cases_12mo * 0.75
gen cancer_9mo_popest = cases_9mo / denominator * 100
gen cancer_12mo_popest = cases_12mo / denominator * 100 

*Keep all cancers only 
keep if cancer_site_number == 1
drop if gender =="Total"
drop if agegroup == 99
drop cancer_site_number cancer_site_desc

*Prep vars for linkage
rename agegroup agegroup_5yr_85to99

*Rename gender variables
gen byte male = 0
replace male = 1 if gender == "M"
label define male 0 "Women" 1 "Men"
label values male male
drop gender

sort  male agegroup_5yr
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
save genpop_1.0_20052021.dta, replace
