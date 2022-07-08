*****************************************
* 6. Sort symptom events 
*****************************************
* Sort symptom events chronologically
* Flag first eligible symptom < 12 months before index fatigue presentation
* Flag first eligible symptom < 3 months after index fatigue presentation
* Send to SQL to add to 'one-row per patient' analysis file in SQL
*****************************************

clear
set seed 4716754

*-------------------------------------------------------------------------
* Get data

* Read data in from SQL
odbc load, exec("select * from becky.fat2_allsymptoms_clin") clear dsn(becky_new)

*Compress
compress

*Check must be met before continuing - 11029309	records
egen count_check = count(epatid)
assert count_check==11029309
drop count_check

*Check: haematuria - 4,278 rows
egen count_check = count(epatid) if symptom_number == 9
assert count_check==4278 if symptom_number == 9
drop count_check

*Check: 'nipple changes' -  xxx rows
egen count_check = count(epatid) if symptom_number == 5
assert count_check==xxx if symptom_number == 5
drop count_check

*Save
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
save "fat2_othersymptoms_elig_ranked", replace
use "fat2_othersymptoms_elig_ranked", clear

*Compress
compress

*-------------------------------------------------------------------------
* Rank symptoms

* Count days between event and fatigue index date
gen daysdiff_fatindex = eventdate - fatigue_date

* Flag 'other event'
tab symptom_number, m
replace symptom_number = 0 if symptom_number == .

*Rank LATEST eligible symptom within 12 months before or same day as fatigue index date
levelsof symptom_number, local(levels)
foreach x of local levels {

gen symp_`x'_date_12mbf = eventdate if symptom_num == `x' & elig_event == 1 & daysdiff_fatindex >= -365 & daysdiff_fatindex <= 0 
format symp_`x'_date_12mbf %td
bysort epatid (symp_`x'_date_12mbf): egen symp_`x'_latest_12mbf =rank(-symp_`x'_date_12mbf) , unique // Latest occurrence
drop symp_`x'_date_12mbf
}

*Rank earliest symptom within 12 months after fatigue index date
levelsof symptom_number, local(levels)
foreach x of local levels {

gen symp_`x'_date_3ma = eventdate if symptom_num == `x' & elig_event == 1 & daysdiff_fatindex <= 91 & daysdiff_fatindex > 0
format symp_`x'_date_3ma %td
bysort epatid (symp_`x'_date_3ma): egen symp_`x'_earliest_3ma =rank(symp_`x'_date_3ma) , unique // earliest occurrence
drop symp_`x'_date_3ma
}


*-------------------------------------------------------------------------
* Save data
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
save "fat2_othersymptoms_elig_ranked_c", replace
use "fat2_othersymptoms_elig_ranked_c", clear

*Compress
compress


*-------------------------------------------------------------------------
*Checks

*Check must be met before continuing - no. records
egen count_check = count(epatid)
assert count_check==11029309
drop count_check

*Check: Haematuria 3 months before - 1 month after
egen count_check = count(epatid) if symptom_number == 9 & elig_event == 1 & (daysdiff_fatindex > -91 & daysdiff_fatindex < 30.4) 
assert count_check==724 if symptom_number == 9 & elig_event == 1 & (daysdiff_fatindex > -91 & daysdiff_fatindex < 30.4) 
drop count_check

*Check: weight loss 3 months before - 1 month after
egen count_check = count(epatid) if symptom_number == 15 & elig_event == 1 & (daysdiff_fatindex > -91 & daysdiff_fatindex < 30.4) 
assert count_check==1991 if symptom_number == 15 & elig_event == 1 & (daysdiff_fatindex > -91 & daysdiff_fatindex < 30.4) 
drop count_check


*-------------------------------------------------------------------------
* Export back to SQL

*Drop vars
drop cancer_date fatigue_date

*Reformat date variables
gen eventdate2 = string(eventdate, "%tdCYMD")
drop eventdate
rename eventdate2 eventdate

*Compress
compress

*Drop previous table in SQL
odbc exec ("Drop table if exists becky.fat2_othersymptoms_elig_ranked"), dsn(becky_new)

* Create the table in SQL
odbc insert, dsn(becky_new) table(fat2_othersymptoms_elig_ranked) create 


*-------------------------------------------------------------------------
* Continue in Stata file 7.
*-------------------------------------------------------------------------