*****************************************
* 6. Sort test events 
*****************************************
* Sort test events chronologically
* Flag first eligible test < 12 months before index fatigue presentation
* Flag first eligible test < 3 months after index fatigue presentation
* Send to SQL to add to 'one-row per patient' analysis file in SQL
*****************************************

clear
set seed 4716754

*-------------------------------------------------------------------------
* Get data

* Read data in from SQL
odbc load, exec("select * from becky.fat2_alltests_elig") clear dsn(becky_new)

*Compress
compress

*Check must be met before continuing - no. rows
egen count_check = count(epatid)
assert count_check==16504439
drop count_check

*Save
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
save "fat2_tests_elig_ranked", replace
use "fat2_tests_elig_ranked", clear

*Compress
compress


*-------------------------------------------------------------------------
*Categorise tests identified using 'other' enttypes + Read codes into the respective test 
replace test_number = 104 if test_number == 26
replace test_number = 106 if test_number == 28
replace test_number = 107 if test_number == 29


*-------------------------------------------------------------------------
*  Hb variables

*Incorrect readterms for haemoglobin are ineligible (neutrophil count): 6 
replace elig_event = . if test_number == 108 & medcode == 18

*Create Hb variable:
*Create Hb variable using main unit (g/ Dl)
gen value = data2 if test_number == 108 & data3 == 56

*Convert g/L to g/Dl and add to Hb variable
replace value = data2 / 10 if test_number == 108 & data3 == 57

*Add data with unspecified unit, if it conforms to possible g/Dl range & is verified by qualifier variable
replace value = data2 if test_number == 108 & data3 == 0 & data2 > 3 & data2 < 25 & inlist(data4, 9, 10, 12, 40, 41)

*Add data with unspecified unit and convert to g/Dl, if it conforms to possible g/l range & is verified by qualifier variable
replace value = data2/ 10 if test_number == 108 & data3 == 0 & data2 > 30 & data2 < 250 & inlist(data4, 9, 10, 12, 40, 41) // testqualifier = normal, low, abnormal, high

*Check for any remaining impossible g/Dl values?
replace value = . if test_number == 108 & (value < 3 | value >= 25)

*Create abnormal Hb flag
gen abnormal = 0 if test_number == 108
replace abnormal = 1 if value < 13 & gender == 1
replace abnormal = 1 if value < 12 & gender == 2

*-------------------------------------------------------------------------
*Rank LATEST symptom within 12 months before or same day as fatigue index date

* Count days between event and fatigue index date
gen daysdiff_fatindex = eventdate - fatigue_date

*For use of test
levelsof test_number, local(levels)
foreach x of local levels {

gen test_`x'_date_12mbf = eventdate if test_number == `x' & /*test_12mbefore == 1 &*/ elig_event == 1 & daysdiff_fatindex >= -365 & daysdiff_fatindex <= 0 
format test_`x'_date_12mbf %td
bysort epatid (test_`x'_date_12mbf): egen test_`x'_latest_12mbf =rank(-test_`x'_date_12mbf) , unique // Latest occurrence
drop test_`x'_date_12mbf
}

*For abnormal test result (currently just anaemia)
levelsof test_number, local(levels)
foreach x of local levels {

gen test_ab_`x'_date_12mbf = eventdate if test_number == `x' & /*test_ab_12mbefore == 1 &*/ elig_event == 1 & daysdiff_fatindex >= -365 & daysdiff_fatindex <= 0 & abnormal == 1
format test_ab_`x'_date_12mbf %td
bysort epatid (test_ab_`x'_date_12mbf): egen test_ab_`x'_latest_12mbf =rank(-test_ab_`x'_date_12mbf) , unique // Latest occurrence
drop test_ab_`x'_date_12mbf
}


*Check
sort epatid eventdate test_number

br epatid eventdate fatigue_date test_108_latest_12mbf  test_ab_108_latest_12mbf  daysdiff_fatindex elig_event abnormal if test_number == 108 & abnormal == 1 & elig_event == 1 &(daysdiff_fatindex > -91 | daysdiff_fatindex < 30.4)


*-------------------------------------------------------------------------
*Rank earliest symptom within 12 months after fatigue index date

*Use of test
levelsof test_number, local(levels)
foreach x of local levels {

gen test_`x'_date_3ma = eventdate if test_number == `x' & elig_event == 1 & daysdiff_fatindex <= 91 & daysdiff_fatindex > 0 & (eventdate <= cancer_date | cancer_date ==. )
format test_`x'_date_3ma %td
bysort epatid (test_`x'_date_3ma): egen test_`x'_earliest_3ma =rank(test_`x'_date_3ma) , unique
drop test_`x'_date_3ma
}

*For abnormal test result (currently just anaemia)
levelsof test_number, local(levels)
foreach x of local levels {

gen test_ab_`x'_date_3ma = eventdate if test_number == `x' & elig_event == 1 & daysdiff_fatindex <= 91 & daysdiff_fatindex > 0 & (eventdate <= cancer_date | cancer_date ==. ) & abnormal == 1
format test_ab_`x'_date_3ma %td
bysort epatid (test_ab_`x'_date_3ma): egen test_ab_`x'_earliest_3ma =rank(test_ab_`x'_date_3ma) , unique
drop test_ab_`x'_date_3ma
}


*Check
sort epatid eventdate test_number

br epatid eventdate fatigue_date  test_ab_108_latest_12mbf  test_ab_108_earliest_3ma daysdiff_fatindex elig_event abnormal if test_number == 108 & abnormal == 1 & elig_event == 1 &(daysdiff_fatindex > -91 | daysdiff_fatindex < 30.4)

*Should currently only be for haemoglobin (108) - all other tests blank
tab2  test_ab_108_latest_12mbf test_number, m


*-------------------------------------------------------------------------
* Save data
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
save "fat2_tests_elig_ranked_c", replace
use "fat2_tests_elig_ranked_c", clear

*-------------------------------------------------------------------------
* Drop data not needed
drop cancer_date  data1 data2 data3 data4 data5 data6 data7 data8 data1_lkup_desc data1_lkup data2_lkup_desc data2_lkup data3_lkup_desc data3_lkup data4_lkup_desc data4_lkup data5_lkup_desc data5_lkup data6_lkup_desc data6_lkup data7_lkup_desc data7_lkup data8_lkup_desc data8_lkup 

*Compress
compress

*Drop rows for tests other than haemoglobin
keep if test_number == 108

*-------------------------------------------------------------------------
*Checks before exporting back to SQL

*Check must be met before continuing - no. records
egen count_check = count(epatid)
assert count_check==476544
drop count_check

*check: number of elig hb values -
egen count_check = count(epatid) if test_number == 108 & value != . & elig_event == 1
assert count_check==469310 if test_number == 108 & value != . & elig_event == 1
drop count_check

*check: number of low hb values 12 months before
egen count_check = count(epatid) if test_number == 108 & abnormal == 1 & elig_event == 1 & test_ab_108_latest_12mbf != .
assert count_check==73137 if test_number == 108 & abnormal == 1 & elig_event == 1 & test_ab_108_latest_12mbf != .
drop count_check

*Check: number of low hb values 12 months before
egen count_check = count(epatid) if test_number == 108 & abnormal == 1 & elig_event == 1 & daysdiff_fatindex > -365 & daysdiff_fatindex <= 0
assert count_check==72943 if test_number == 108 & abnormal == 1 & elig_event == 1 & daysdiff_fatindex > -365 & daysdiff_fatindex <= 0
drop count_check

*check number of low hb values 3 months before - 1 month after :  37,011 patients, 53,858 records
egen count_check = count(epatid) if test_number == 108 & abnormal == 1 & elig_event == 1 &(daysdiff_fatindex > -91 & daysdiff_fatindex < 30.4)
assert count_check==53858 if test_number == 108 & abnormal == 1 & elig_event == 1 &(daysdiff_fatindex > -91 & daysdiff_fatindex < 30.4)
drop count_check


*-------------------------------------------------------------------------
* Export back to SQL

*Reformat date variables
gen eventdate2 = string(eventdate, "%tdCYMD")
drop eventdate
rename eventdate2 eventdate

*Drop previous table in SQL
odbc exec ("Drop table if exists becky.fat2_tests_elig_ranked"), dsn(becky_new)

* Create the table in SQL
odbc insert, dsn(becky_new) table(fat2_tests_elig_ranked) create 

*-------------------------------------------------------------------------
* Continue in SQL file 8.
*-------------------------------------------------------------------------

exit 1 


/*
*-------------------------------------------------------------------------
*Appendix: Record of checks
*-------------------------------------------------------------------------

* Which symptoms are captured by 'other event' in enttype?
tab test_number if enttype == 288, m

*Which symptom numbers are there
* Note if other enttype 288 used, the symptom numbers need to be changed
tab2 test_desc test_number, m

*Check for eligible tests
*Check read codes are all correct for 173 haemoglobin enttype
tab readcode_desc if test_number == 108, m
tab2 readcode_desc medcode if test_number == 108, m // neutrophil count (medcode 18) incorrect  

*Check unit type used
tab2 unitmeasure data3 if test_number == 108, m


*Check range of values against unit of measurement
	*No data entered: 2,079 records mean 24 min 0 max 174
			What to do with these? There is a value in data2 but unit not specified
			KEEP SOME - see below
	*%: IMPOSSIBLE UNIT - DROP 
	*g/DL: mean 13. Min .2 max 4095  *** Most common 355,000 records. KEEP
	*g/L: mean 131 min 0 max 1336. KEEP
	*mg/L: 1 RECORD - DROP
	*mmol/mol: IMPOSSIBLE UNIT - DROP 
	*g/kg: IMPOSSIBLE UNIT - DROP 

preserve
keep if test_number==108
labmask data3, values(unitmeasure)
sort data3
by data3: summ data2 data5 data6
restore

*Explore no unit specified
*Main peak is in Dl range with smaller peak in /l range
hist data2 if test_number == 108 & data3 == 0

*Check whether readcodes can verify some values from this section
tab testqualifier if test_number == 108 & data3 == 0, m
tab testqualifier if test_number == 108 & data3 == 0 & data2 > 1 & data2 < 40, m
tab testqualifier if test_number == 108 & data3 == 0 & data2 > 100 & data2 < 140, m
tab2 testqualifier data4 if test_number== 108 & data3 == 0 & data2 > 1 & data2 < 40 // 9, 10, 12, 40, 41 could verify the value