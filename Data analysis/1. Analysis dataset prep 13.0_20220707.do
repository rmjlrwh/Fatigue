*****************************************
* 1. Analysis dataset prep
*****************************************

clear
/******************************************************************************/
** Frame set up

/* Create useful frames */
frame change default

foreach newframe in raw_data_prep symptom_labels {
	cap frame `newframe': clear
	cap frame drop `newframe'
	frame create `newframe'
}

/******************************************************************************/
** Symptom lookup
/******************************************************************************/

frame change symptom_labels

import delimited "S:\ECHO_IHI_CPRD\Phenotypes\In development\Symptom test cohorts extract 2.2\Symptom_lookup_1.0_20220706_tab_short.txt", clear 

collapse (count) medcode, by (symptom_number symptom_desc alarm_vague)
sort alarm_vague symptom_number

*Add labels for 'overall' groups
set obs `=_N+1'
replace symptom_number = 100 if symptom_number == .
replace symptom_desc = "All patients with fatigue" if symptom_number == 100

set obs `=_N+1'
replace symptom_number = 300 if symptom_number == .
replace symptom_desc = "With alarm symptoms" if symptom_number == 300

set obs `=_N+1'
replace symptom_number = 301 if symptom_number == .
replace symptom_desc = "Without alarm symptoms" if symptom_number == 301

set obs `=_N+1'
replace symptom_number = 400 if symptom_number == .
replace symptom_desc = "With anaemia" if symptom_number == 400

set obs `=_N+1'
replace symptom_number = 401 if symptom_number == .
replace symptom_desc = "Without anaemia" if symptom_number == 401

set obs `=_N+1'
replace symptom_number = 500 if symptom_number == .
replace symptom_desc = "Without alarm symptoms or anaemia" if symptom_number == 500

set obs `=_N+1'
replace symptom_number = 600 if symptom_number == .
replace symptom_desc = "With vague symptoms" if symptom_number == 600

set obs `=_N+1'
replace symptom_number = 700 if symptom_number == .
replace symptom_desc = "Without vague symptoms" if symptom_number == 700


* neaten
replace symptom_desc = trim(symptom_desc)

*Create labels
labmask symptom_number, values(symptom_desc)

*Save
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
save "symptom_lookup", replace


*************************************************************
** Section A) Load data

frame change raw_data_prep

/*

* 1. Read data in from SQL
odbc load, exec("select * from becky.fat2_dataset_characterisation_2") clear dsn(becky_new)

* Check data

*Should be date values in every column - if not, it will throw an error 
*If dates are not loading, restart stata
local allsymp "3 4 5 6 9 10 11 13 14 16 30 31 32 33 34 35 1 2 7 12 15 17 18 19 20 21 22 36 37 38 39 40 43 44 45"
foreach i of local allsymp {
 codebook symp_date_latest_12mbf_`i' if symp_date_latest_12mbf_`i' != .
 codebook symp_date_earliest_3ma_`i' if symp_date_earliest_3ma_`i' !=.
}

*Check: no. rows
egen count_check = count(epatid)
assert count_check==285382
drop count_check

*Check: no. pelvic pain
egen count_check = count(epatid) if symp_date_latest_12mbf_20 !=.  
assert count_check==299 if symp_date_latest_12mbf_20 !=. 
drop count_check

*Check: no. haemoglobin values 
egen count_check = count(epatid) if test_ab_date_earliest_3ma_108 !=.  
assert count_check==29889 if test_ab_date_earliest_3ma_108 !=. 
drop count_check

*Check: symp/ test dates are before cancer diagnosis
assert symp_date_latest_12mbf_15 <= cancer_date if symp_date_latest_12mbf_15 != .
assert test_ab_date_earliest_3ma_108 <= cancer_date if test_ab_date_earliest_3ma_108 != .

*Compress
compress

* Save data
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
save "Symptoms_ppvs_2_a", replace

*/

* Use data
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
use "Symptoms_ppvs_2_a", clear

*Compress
compress

*************************************************************
** Section B) Create additional variables (age at index, age group, symptom flags etc.)

*Destring numeric
destring cancer_site_number, replace

*Create 9 month cancer flag	
gen cancer_9mo = 0
replace cancer_9mo = 1 if cancer_date  <=  (fatigue_date + 274) & cancer_date  !=.

* Create age at index date
gen age_idate = year(fatigue_date)- d_yob

*Recode patients aged 100 as 99 (as dob is approximate)
replace age_idate = 99 if age_idate == 100

* Create age groups at index dates
label define agegroup 99 "All ages" 0 "<30" 30 "30-49" 50 "50-69" 70 "70-99"
egen agegroup = cut(age_idate), at(0,30,50,70,140)
label values agegroup agegroup

* 10 year age band
label define agegroup10yr 99 "All ages" 0 "<30" 30 "30-39" ///
40 "40-49" ///
50 "50-59" ///
60 "60-69" ///
70 "70-79" ///
80 "80-89" ///
90 "90-99"

egen agegroup_10yr = cut(age_idate), at(0,30,40,50,60,70,80,90,140)
label values agegroup_10yr agegroup10yr

* 5 year age band
label define agegroup5yr 99 "All ages" 0 "<30" 30 "30-34" ///
35 "35-39" 40 "40-44" ///
45 "45-49" 50 "50-54" ///
55 "55-59" 60 "60-64" ///
65 "65-69" 70 "70-74" ///
75 "75-79" 80 "80-84" ///
85 "85-89" 90 "90-94" ///
95 "95-99" 

egen agegroup_5yr = cut(age_idate), at(0,30,35,40,45,50,55,60,65,70,75,80,85,90,95,140)
label values agegroup_5yr agegroup5yr

*Rename gender variables
gen byte male = gender == 1
label define male 0 "Women" 1 "Men"
label values male male

*Not interested in fatigue on same day as index date
replace symp_date_latest_12mbf_8 = . if symp_date_latest_12mbf_8 == fatigue_date // all records should change
replace symp_date_earliest_3ma_8 = . if symp_date_earliest_3ma_8 == fatigue_date // should have 0 changes

*Should be 0 patients with fatigue before the first fatigue index dates
tab symp_date_latest_12mbf_8, m

*Create cancer site within 9 months variables
gen cancer_site_number_9mo = cancer_site_number if cancer_9mo == 1
gen cancer_site_desc_9mo = cancer_site_desc if cancer_9mo == 1


*************************************************************
*Clean impossible values

*Testicular pain & testicular lump in women (symp numbers 34 37)
foreach i in 34 38 {
replace symp_date_latest_12mbf_`i' = . if male == 0
replace symp_date_earliest_3ma_`i' = . if male == 0
}

*PM bleed in men
foreach i in 13 {
replace symp_date_latest_12mbf_`i' = . if male == 1
replace symp_date_earliest_3ma_`i' = . if male == 1
}

*************************************************************
*Symptom cohort flags

*Date of most recent symptom
*If x months before/ 3m after flag
global symp "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 43 44 45"

foreach i of global symp {

*Flag months before fatigue
gen symp_mbefore_`i' = .
replace symp_mbefore_`i' = datediff_frac( symp_date_latest_12mbf_`i', fatigue_date, "month") if  symp_date_latest_12mbf_`i' <= fatigue_date
gen symp_mbefore_r_`i' = 1 * ceil(symp_mbefore_`i'/1)

*Flag months after fatigue
gen symp_mafter_`i' = . 
replace symp_mafter_`i' = datediff_frac(fatigue_date, symp_date_earliest_3ma_`i', "month")  if  symp_date_earliest_3ma_`i' > fatigue_date 
gen symp_mafter_r_`i' = 1 * ceil(symp_mafter_`i'/1)

*Flag symptom occurring x months before - 1 month after fatigue
foreach x of numlist 1 2 3 4 5 6 7 8 9 10 11 12 {
gen symp_`x'mb_1ma_`i' = 0
replace symp_`x'mb_1ma_`i' = 1 if (symp_mbefore_`i' < `x' & symp_mbefore_`i' < .) | (symp_mafter_r_`i' <= 1)
}

*Add record on same day as fatigue
gen symp_0mb_1ma_`i' = 0
replace symp_0mb_1ma_`i' = 1 if symp_mbefore_`i' == 0
}


*************************************************************
*Test cohort flags


*Date of most recent test
*If x months before/ 3m after flag
global test "108"

foreach i of global test {

*Flag months before fatigue
gen test_mbefore_`i' = .
replace test_mbefore_`i' = datediff_frac(test_date_latest_12mbf_`i', fatigue_date, "month")  if  test_date_latest_12mbf_`i' <= fatigue_date
gen test_mbefore_r_`i' = 1 * ceil(test_mbefore_`i'/1)

*Flag months after fatigue
gen test_mafter_`i' = . 
replace test_mafter_`i' = datediff_frac(fatigue_date, test_date_earliest_3ma_`i', "month") if test_date_earliest_3ma_`i' > fatigue_date 
gen test_mafter_r_`i' = 1 * ceil(test_mafter_`i'/1)

*Flag symptom occurring x months before - 1 month after fatigue
foreach x of numlist 1 2 3 4 5 6 7 8 9 10 11 12 {
gen test_`x'mb_1ma_`i' = 0
replace test_`x'mb_1ma_`i' = 1 if (test_mbefore_`i' < `x' & test_mbefore_`i' < .) | (test_mafter_r_`i' <= 1)
}

gen test_0mb_1ma_`i' = 0
replace test_0mb_1ma_`i' = 1 if test_mbefore_`i' == 0
}


*************************************************************
*Abnormal test result cohort flags

*Date of most recent symptom
*If x months before/ 3m after flag
global abtest "108"

foreach i of global abtest {

gen test_ab_mbefore_`i' = .
replace test_ab_mbefore_`i' = datediff_frac(test_ab_date_latest_12mbf_`i', fatigue_date, "month")  if  test_ab_date_latest_12mbf_`i' <= fatigue_date
gen test_ab_mbefore_r_`i' = 1 * ceil(test_ab_mbefore_`i'/1)

gen test_ab_mafter_`i' = . 
replace test_ab_mafter_`i' = datediff_frac(fatigue_date, test_ab_date_earliest_3ma_`i', "month")  if  test_ab_date_earliest_3ma_`i' > fatigue_date
gen test_ab_mafter_r_`i' = 1 * ceil(test_ab_mafter_`i'/1)

foreach x of numlist 1 2 3 4 5 6 7 8 9 10 11 12 {
gen test_ab_`x'mb_1ma_`i' = 0
replace test_ab_`x'mb_1ma_`i' = 1 if (test_ab_mbefore_`i' < `x' & test_ab_mbefore_`i' < .) | (test_ab_mafter_r_`i' <= 1)
}

gen test_ab_0mb_1ma_`i' = 0
replace test_ab_0mb_1ma_`i' = 1 if  test_ab_mbefore_`i' == 0
}


*************************************************************
*Grouped flag - Alarm symptoms/ non-alarm symptoms / test result


*All patients flag - for totals
foreach x of numlist 0 1 2 3 4 5 6 7 8 9 10 11 12 {
gen symp_`x'mb_1ma_100 = 1
}

*Alarm symptom flag (excl anaemia)
local 300 "3 4 5 6 9 10 11 13 14 16 30 31 32 33 34 35"
foreach x of numlist 0 1 2 3 4 5 6 7 8 9 10 11 12 {
gen symp_`x'mb_1ma_300 = 0
foreach i of local 300 {
replace symp_`x'mb_1ma_300 = 1 if symp_`x'mb_1ma_`i' == 1
}
}

*No alarm symptom flag
local 300 "3 4 5 6 9 10 11 13 14 16 30 31 32 33 34 35"
foreach x of numlist 0 1 2 3 4 5 6 7 8 9 10 11 12 {
gen symp_`x'mb_1ma_301 = 0
replace symp_`x'mb_1ma_301 = 1 if symp_`x'mb_1ma_300 == 0
}

*Anaemia flag
foreach x of numlist 0 1 2 3 4 5 6 7 8 9 10 11 12 {
	gen symp_`x'mb_1ma_400 = 0
replace symp_`x'mb_1ma_400 = 1 if test_ab_`x'mb_1ma_108 == 1
}

*No anaemia flag
foreach x of numlist 0 1 2 3 4 5 6 7 8 9 10 11 12 {
	gen symp_`x'mb_1ma_401 = 0
replace symp_`x'mb_1ma_401 = 1 if test_ab_`x'mb_1ma_108 == 0
}

*No alarm symptom or anaemia flag
foreach x of numlist 0 1 2 3 4 5 6 7 8 9 10 11 12 {
gen symp_`x'mb_1ma_500 = 0
replace symp_`x'mb_1ma_500 = 1 if symp_`x'mb_1ma_300!= 1 & symp_`x'mb_1ma_400!= 1
}

*Non-alarm symptom flag
local 600 "1 2 7 12 15 17 18 19 20 21 22 36 37 38 39 40 43 44 45"

foreach x of numlist 0 1 2 3 4 5 6 7 8 9 10 11 12 {
gen symp_`x'mb_1ma_600 = 0
foreach i of local 600 {
replace symp_`x'mb_1ma_600 = 1 if symp_`x'mb_1ma_`i' == 1
}
}

*No other non-alarm symptom flag
foreach x of numlist 0 1 2 3 4 5 6 7 8 9 10 11 12 {
gen symp_`x'mb_1ma_700 = 0
replace symp_`x'mb_1ma_700 = 1 if symp_`x'mb_1ma_600!= 1
}

*Count of number of nonalarm symptom combinations
gen symp_3mb_1ma_count = 0
foreach i of numlist 1 2 7 12 15 17 18 19 20 21 22 36 37 38 39 40 43 44 45 {
replace symp_3mb_1ma_count = symp_3mb_1ma_count + (symp_3mb_1ma_`i' == 1)
}

*Patients with 2 or more additional symptoms
gen symp_3mb_1ma_2combos = .
replace symp_3mb_1ma_2combos = 1 if symp_3mb_1ma_count == 0
replace symp_3mb_1ma_2combos = 2 if symp_3mb_1ma_count == 1
replace symp_3mb_1ma_2combos = 3 if symp_3mb_1ma_count >= 2


*************************************************************
*Symptom labels


*Add labels
label define yesno 0 "No" 1 "Yes"
local vars "symp_*mb_*ma_* test_ab_*mb_*ma_*"
foreach v of local vars {
   label values `v' yesno
}
label values symp_3mb_1ma_count
label values symp_3mb_1ma_2combos

frame symptom_labels: qui levelsof symptom_number, local(symptoms)

 qui foreach symptom in `symptoms' {
	frame symptom_labels: local symp_desc : label (symptom_number) `symptom'
	qui foreach i of num 1/12 {
	label variable symp_`i'mb_1ma_`symptom' "`symp_desc'"
}		
}

*Main labels
	label var epatid "Patient ID"
	label var age_idate "Age at entry, years"
	label var agegroup "Age at entry, broad age group"
	label var agegroup_10yr "Age at entry, 10-year bands"
	label var agegroup_5yr "Age at entry, 5-year bands"
	label var cancer_9mo "Cancer, binary 0/1"
	label var male "Male, binary 0/1"
	label var symp_3mb_1ma_8 "Fatigue, excl same day as index"
	label var symp_3mb_1ma_count "Number of additional vague symptoms"
	label var symp_3mb_1ma_2combos "Number of additional vague symptoms"

	
*************************************************************
*Final checks and save


*All patients without alarm symptoms or anaemia had no alarm symp x and no anaemia
assert  symp_3mb_1ma_3==0 if symp_3mb_1ma_500 == 1
assert  symp_3mb_1ma_300==0 if symp_3mb_1ma_500 == 1
assert  symp_3mb_1ma_400==0 if symp_3mb_1ma_500 == 1

*Check frequency alarm symptoms
local 300 "300 3 4 5 6 9 10 11 13 14 16 30 31 32 33 34 35"
foreach i of local 300 {
tab2 symp_3mb_1ma_`i' male
}

*Check frequency non alarm symptoms
local nonalarm "700 1 2 7 12 15 17 18 19 20 21 22 36 37 38 39 40 43 44 45"
foreach i of local nonalarm {
tab2 symp_3mb_1ma_`i' male
}

*Check correct number of men without alarm symptoms or anaemia
egen count_check = count(epatid) if male & symp_3mb_1ma_500
assert count_check==78471  if male & symp_3mb_1ma_500
drop count_check

*Check correct number of men (without alarm symptoms or anaemia) with nonalarm symptom
egen count_check = count(epatid) if male & symp_3mb_1ma_500 & symp_3mb_1ma_600
assert count_check==28528  if male & symp_3mb_1ma_500 & symp_3mb_1ma_600
drop count_check

compress

save "Symptoms_ppvs_2_c", replace
