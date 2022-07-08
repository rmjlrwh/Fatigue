*****************************************
* 2. Sort fatigue events 
*****************************************
* Sort fatigue events chronologically
* Flag index presentation (first eligible fatigue event)
* Send to SQL to create fatigue cohort in SQL
*****************************************

clear 
set seed 342998

*-------------------------------------------------------------------------
* Get data

* Read data in from SQL
odbc load, exec("select * from becky.fat2_fatiguecancers_events") clear dsn(becky_new)

*Destring case variables
destring eventtype validfat, replace

*Save
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
save "fat2_fatiguecancer_events_elig_ranked", replace
use "fat2_fatiguecancer_events_elig_ranked", clear

*-------------------------------------------------------------------------
* Check data

sort eventdate
br eventdate validfat eventtype if validfat==1 & eventtype == 1

*Check must be met before continuing

*No. valid fatigue records
egen count_check = count(epatid) if validfat== 1  & eventtype == 1
assert count_check==446110 if validfat== 1  & eventtype == 1
drop count_check

*No. cancers
egen count_check = count(epatid) if eventtype == 2
assert count_check==27090 if eventtype == 2
drop count_check

*-------------------------------------------------------------------------
* 3. Flag date of previous fatigue presentations and cancers 

* To reproduce the same sorting of events when a cancer and symptom occur on the same day, this sort ensures cancer always occurs after the symptom, if on the same day.
bysort epatid (eventdate eventtype): gen prev_cancer = eventdate[_n-1] if eventtype[_n-1] == 2
format prev_cancer %td

*Fill in prev cancers if prev cancer more than one row above 
bysort epatid (eventdate eventtype): replace prev_cancer = prev_cancer[_n-1] if prev_cancer == .

* Prev fatigue for fatigue presentations
bysort epatid (eventdate eventtype): gen prev_fatigue = eventdate[_n-1] if eventtype[_n-1] == 1
format prev_fatigue %td

*Fill in prev fatigue if prev fatigue more than one row above
bysort epatid (eventdate eventtype): replace prev_fatigue = prev_fatigue[_n-1] if prev_fatigue == .

*-------------------------------------------------------------------------
*Flag events with prev fatigue or cancer < x years before

* Flag event with prev fatigue < 1 year before
gen prev_fatigue_1yr = 0
replace prev_fatigue_1yr = 1 if eventdate - prev_fatigue < 365

* Flag event with prev cancer < 1 year before
gen prev_cancer_1yr = 0
replace prev_cancer_1yr = 1 if eventdate - prev_cancer < 365

*-------------------------------------------------------------------------
* Order fatigue presentations if valid and no fatigue or cancer < 1 year before

*Flag first valid, excluding fatigue or cancer < 1 year
gen fdate_v_fc1yr = eventdate if eventtype == 1 & validfat==1 & prev_fatigue_1yr == 0 & prev_cancer_1yr == 0
format fdate_v_fc1yr %td
bysort epatid (fdate_v_fc1yr): egen forder_v_fc1yr =rank(fdate_v_fc1yr) , unique


*-------------------------------------------------------------------------
*Keep fatigue index date
preserve
keep if forder_v_fc1yr == 1
codebook epatid
keep epatid eventdate origin_id
rename eventdate fat_index_date
rename origin_id fat_index_id
save "fatigue_index_dates", replace
restore

*-------------------------------------------------------------------------
*Merge in fatigue index date
merge m:1 epatid using "fatigue_index_dates"
sort epatid eventdate eventtype
drop _merge

*-------------------------------------------------------------------------
* Count days between event and fatigue index date
gen daysdiff_fatindex = eventdate - fat_index_date

*Rank first cancer diagnosis after fatigue index date
gen cancer_date = eventdate if eventtype == 2 & daysdiff_fatindex >= 0
format cancer_date %td
bysort epatid (cancer_date origin_code): egen cancer_order =rank(cancer_date) , unique

codebook epatid if cancer_order == 1 // should be 19,361 and should be unique 
* note not all of the cancer_order == 1s will be for patients with an eligible fatigue record

*-------------------------------------------------------------------------
* Save list of first cancers

*Keep first cancer - should be 19,361
preserve
keep if cancer_order == 1
codebook epatid
keep epatid eventdate origin_id cancer_site_number cancer_site_desc
rename eventdate first_cancer_date
rename origin_id first_cancer_id
rename cancer_site_number first_cancer_type
rename cancer_site_desc first_cancer_desc
save "cancer_dates", replace
restore

*-------------------------------------------------------------------------
*Merge in fatigue index date
merge m:1 epatid using "cancer_dates"
sort epatid eventdate eventtype
drop _merge

*Flag if first cancer < 9 months
gen first_cancer_9months = .
replace first_cancer_9months = 1 if first_cancer_date - fat_index_date <= 274


*-------------------------------------------------------------------------
*Checks

*No. records of valid (potentially eligible) fatigue, with no fatigue or cancer diagnosis in prev year
egen count_check = count(epatid) if eventtype == 1  & validfat==1 & prev_fatigue_1yr == 0 & prev_cancer_1yr == 0
assert count_check==343390 if eventtype == 1  & validfat==1 & prev_fatigue_1yr == 0 & prev_cancer_1yr == 0
drop count_check

*No. patients with an index fatigue presentation
duplicates tag epatid if forder_v_fc1yr == 1, gen(dup_tag)
egen count_check = count(dup_tag) if dup_tag == 0
assert count_check == 285382 if dup_tag == 0
drop dup_tag count_check

*Eligible fatigue presentations are valid (potentially eligible), with no fatigue or cancer diagnosis in prev year
assert forder_v_fc1yr !=. if eventtype == 1  & validfat==1 & prev_fatigue_1yr == 0 & prev_cancer_1yr == 0 

*-------------------------------------------------------------------------
*Cohort inclusions and exclusions

*See SQL: Patients a record of CPRD within overall stud period

*Patients with an eligible record of fatigue
codebook epatid if validfat== 1  & eventtype == 1 // 292,228 unique

*Patients with no other fatigue record in the previous year
codebook epatid if eventtype == 1  & validfat==1 & prev_fatigue_1yr == 0 // 288,715

*Patients with no cancer diagnosis in the previous years
codebook epatid if eventtype == 1  & validfat==1 & prev_fatigue_1yr == 0 & prev_cancer_1yr == 0 //  285,382
codebook epatid if forder_v_fc1yr != . // 285,382 


*-------------------------------------------------------------------------
* 6. Save data
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
save "fat2_fatigueevents_elig_ranked_ppv", replace

*-------------------------------------------------------------------------

use "fat2_fatigueevents_elig_ranked_ppv", clear

* 6. Export back to SQL
keep origin_id eventtype epatid eventdate origin_code  validfat forder_v_fc1yr cancer_order  deathdate daysdiff_fatindex cancer_site_number cancer_site_desc

*Reformat date variables
gen eventdate2 = string(eventdate, "%tdCYMD")
drop eventdate
rename eventdate2 eventdate

gen deathdate2 = string(deathdate, "%tdCYMD")
drop deathdate
rename deathdate2 deathdate

*Drop previous table in SQL
odbc exec ("Drop table if exists becky.fat2_fatigueevents_elig_ranked"), dsn(becky_new)

* Create the table in SQL
odbc insert, dsn(becky_new) table(fat2_fatigueevents_elig_ranked) create 


*-------------------------------------------------------------------------
* Continue in SQL file 3.
*-------------------------------------------------------------------------
