/******************************************************************************/
* 3. Observed tables/ figures
/******************************************************************************/
* Make sure you clear the stata session if you have just run the dataset prep files, before running this

clear 
/******************************************************************************/
**# Frame setup and handling

/* Create useful frames */
frame change default

foreach newframe in symptom_labels raw_data_1 raw_data_full figure2 figure3   {
	cap frame `newframe': clear
	cap frame drop `newframe'
	frame create `newframe'
}


** Symptom lookup
frame change symptom_labels
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
use "symptom_lookup", clear

*Full data 
frame change raw_data_full
use "Symptoms_ppvs_2_c", clear

*Minimised data using just 3 month co-occurrence vars
frame copy raw_data_full raw_data_1, replace
frame change raw_data_1
keep epatid male age* imd* cancer_9mo symp_3mb_1ma_* test_ab_3mb_1ma_108  
compress

*Checks
tab2 symp_3mb_1ma_500 male
tab2 symp_3mb_1ma_400 symp_3mb_1ma_300 if male


*Check - should be xx men with no alarm symptom/ anaemia, with abdominal bloating (no. 2)
egen count_check = count(epatid) if symp_3mb_1ma_500 & male & symp_3mb_1ma_2
assert count_check== 308  if symp_3mb_1ma_500 & male & symp_3mb_1ma_2
drop count_check

*Change to export folder
cd "S:\ECHO_IHI_CPRD\Becky\Fatigue other symptoms\Table exports\"


/******************************************************************************/
**# Set up programmes

* convenience program for %s
cap program drop prop100
program prop100, rclass
	ci means `1'
	local mean100 = r(mean)*100
	local mean100str = strofreal(`mean100',"%03.2f")
	return local mean = "`mean100str'"
end

* convenience program for CIs
cap program drop ci_prop
program ci_prop, rclass
	ci proportions `1', wilson
	local lb = r(lb)*100
	local ub = r(ub)*100
	local ci = "(" + strofreal(`lb',"%03.2f") + ", " + strofreal(`ub', "%03.2f") + ")"
	return local ci = "`ci'"
end

* convenience program for IQR
cap program drop iqr_prog
program iqr_prog, rclass
	summ `1', detail
	local med = r(p50)
	local lq = r(p25)
	local uq = r(p75)
	local iqr_str = strofreal(`med',"%02.0f") + " (" + strofreal(`lq',"%02.0f") + "-" + strofreal(`uq',"%02.0f") + ")"
	return local iqr = "`iqr_str'"
end


/******************************************************************************/
**# Set up common formatting

/* Set base graph scheme */
set scheme s1color

* some common table formatting
cap program drop common_formatting
program common_formatting

	* hide row title thing
	collect style header cmdset, level(label) title(hide)

	* Label column titles
	collect style header male, level(value)

	collect label levels male 0 "Women" 1 "Men", modify
	collect style header male, level(label) title(hide)

	*Centre column titles
	collect style column, dups(center)

	collect preview
end


/******************************************************************************/
**# Set up table-specific formatting

*table 2
cap program drop table2
program table2

	*Change layout
	collect layout (cmdset) (male#statcmd)

	* fix cell formatting
	collect style cell statcmd[1], nformat("%9.0fc")

	* Label super-column titles
	collect label levels statcmd 1 "Total (N)" 2 "Median (IQR) age (years)", modify

	collect preview
end


*table 3
cap program drop table3
program table3

	* set layout
	collect layout (cmdset) (male#statcmd)

	* fix cell formatting
	collect style cell statcmd[2], nformat("%03.2f")
	collect style cell statcmd[1], nformat("%9.0fc")

	* Label super-column titles
	collect label levels statcmd 1 "Patients" 2 "Prop. cancer" 3 "(95% CI)", modify
	collect style header statcmd, level(label)

	collect preview 
end


*App 4
cap program drop app4
program app4

	*Change layout
	collect layout (cmdset) (var#result)

	global allsymp700 "300 301 400 500 600 700 3 4 5 6 9 10 11 13 14 16 30 31 32 33 34 35 1 2 7 12 15 17 18 19 20 21 22 36 37 38 39 40 43 44 45"

	foreach symptom of global allsymp700   {
		foreach i in 0 3 6 9 12 	{
			collect recode var symp_`i'mb_1ma_`symptom' = symp_`i'mb_1ma_100
			collect recode var symp_`i'mb_1ma_`symptom' = symp_`i'mb_1ma_100
			collect recode var symp_`i'mb_1ma_`symptom'_p = symp_`i'mb_1ma_100
			collect recode var symp_`i'mb_1ma_`symptom'_p = symp_`i'mb_1ma_100
		}	
	}

	*Label super columns
	collect label levels var symp_0mb_1ma_100 "Same day" ///
		symp_3mb_1ma_100 "-3 months/ +1 month" ///
		symp_6mb_1ma_100 "-6 months/ +1 month" ///
		symp_9mb_1ma_100 "-9 months/ +1 month" ///
		symp_12mb_1ma_100 "-12 months/ +1 month", modify
	collect style header var, level(label) title(hide)

	*Label columns
	collect label levels result total "n" mean "%", modify

	* fix cell formatting
	collect style cell result[total], nformat("%9.0fc") halign(center)
	collect style cell result[mean], nformat("%03.1f") halign(center)
	collect preview
end

*App 5
cap program drop app5
program app5

	*Change layout
	collect layout (cmdset) (male#var#result)

	*Label columns
	collect label levels result  mean "%" ci "(95% CI)", modify

	*Label super columns
	collect label levels var symp "Total patients (N)" ///
		cancer_9mo "Patients with cancer (n)", modify
end


*App 6
cap program drop app6
program app6

	* set layout
	collect layout (cmdset) (male#statcmd)

	*Label columns
	collect label levels statcmd 1 "General population (%)" 2 "Fatigued patients, no alarm symptoms/ anaemia (%)" 3 "(95% CI)", modify

	* fix cell formatting
	collect style cell statcmd[1], nformat("%03.2f") halign(center)
	collect preview
end



/******************************************************************************/
**# Table. Number of additional vague symptom combos

*Change frames
frame change default
frame copy raw_data_1 figure2, replace
frame change figure2

*Matt code. Temp stops the temp files clogging up and preventing you from rerunning this code.
tempfile temp
save `temp'

* exlcude those with alarm symptoms or anaemia
drop if symp_3mb_1ma_500 == 0

*Extra % not shown in graph: no. of extra combos with fatigue
collect clear
table (var) (male), ///
	stat(fvfrequency symp_3mb_1ma_count) stat(fvpercent symp_3mb_1ma_count) ///
	name(sympcount)

collect style row stack, nobinder
collect label levels result fvfrequency "Freq." fvpercent "%", modify
collect preview

*Save to word
putdocx clear
putdocx begin
putdocx paragraph
putdocx text ("Number of vague symptoms co-occurring* with fatigue, as a proportion of patients with fatigue and no alarm symptom/ anaemia (%)")

putdocx paragraph
putdocx collect


/******************************************************************************/
**# Figure. Symptom cohort sizes - each non alarm symptom

*Each non alarm symptom
*% and count variables
global allsymp "300 400 500 600 3 4 5 6 9 10 11 13 14 16 30 31 32 33 34 35 1 2 7 12 15 17 18 19 20 21 22 36 37 38 39 40 43 44 45"

foreach i of global allsymp {
	gen symp_3mb_1ma_c_`i' = symp_3mb_1ma_`i'
	rename symp_3mb_1ma_`i' symp_3mb_1ma_p_`i'
}

* calculate % with each symptom by sex
collapse (mean) symp_3mb_1ma_p_* (sum) symp_3mb_1ma_c_* , by(male)

* reshape to nice long format for making brain hurt less
reshape long symp_3mb_1ma_p_ symp_3mb_1ma_c_ , i(male) j(symptom)

*get symtpom label and alarm/ non alarm categorisation
frlink m:1 symptom, frame(symptom_labels symptom_number)
frget symptom_desc, from(symptom_labels)
frget alarm_vague, from(symptom_labels)

* label symptom values for now (may change later)
labmask symptom, values(symptom_desc)

* Keep vague symptoms only (i.e. drop tests and alarm symptoms/ anaemia)
keep if alarm_vague == 2
drop if symptom == 8  // drop fatigue

* mean so same order for both sexes
egen mean = mean(symp_3mb_1ma_p_), by(symptom)
gsort male -mean
by male: gen symptom2 = _n
label var symptom2 "Symptoms in order of occurrence on average"

* label symptom values for now (may change later)
labmask symptom2, values(symptom_desc)

* to percent
gen percent = 100*symp_3mb_1ma_p_

*Gen percent/ N labels
gen lab = string(percent,"%03.1f") + "% (" + string(symp_3mb_1ma_c_,"%6.0fc") + ")"
replace lab = "" if male == 0 & symptom == 38

qui levelsof symptom2, local(labs)
#delimit ;
	graph twoway 
	(bar percent symptom2, horizontal barw(0.7))
	(scatter symptom2 percent,  mlab(lab) mlabpos(3) msymb(none) mlabc(gs0) mlabsize(vsmall))
	, 	by(male, note("") legend(off))  
		ylabel(
			`labs'
			, 	valuelabel 
			angle(h) 
			tl(0) 
			labsize(small) 
		) 
		ysc(reverse)
		ytitle("Symptom")
		xtitle("Proportion (%) of patients with fatigue without alarm symptoms/ anaemia")
		subtitle(, fcolor(gs0) color(gs16) pos(11) )
		plotregion(margin(l=0))
		xsc(r(0 13))
		xlabel(0(2)10, grid)
		name(Fig2, replace)
;
#delimit cr	
graph export Graphs/Fig2.png, width(1000) replace

*Matt code ends
use `temp', clear

*Save to word
putdocx pagebreak
putdocx paragraph
putdocx text ("Patients with each co-occurring symptom*, as a proportion of patients with fatigue and no alarm symptom/ anaemia (%)")

putdocx paragraph
putdocx image "Graphs/Fig2.png", width(12.8cm) height(9.3cm) linebreak(1)


/******************************************************************************/
**# Table. Age characteristics

*Change frames
frame change default
frame copy raw_data_1 tab1, replace
frame change tab1

collect clear

*Check - should be xxx men without alarm symptoms/ anaemia, with abdominal bloating (no. 2)
egen count_check = count(epatid) if symp_3mb_1ma_500 & male & symp_3mb_1ma_2
assert count_check== 308  if symp_3mb_1ma_500 & male & symp_3mb_1ma_2
drop count_check

*Set up temp file
tempfile temp2
save `temp2'

*Collect table rows 

/*All patients */

local table_row 1
foreach symptom in 100 300 301 {

	table () (male) if symp_3mb_1ma_`symptom' == 1, ///
		stat(sum symp_3mb_1ma_100) ///
		command(r(iqr): iqr_prog age_idate) ///
		nototal name(Tab2) append	

	frame symptom_labels: local symp_label : label (symptom_number) `symptom'		/* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row
}

collect label levels cmdset 1 "a) All patients with fatigue", modify
collect label levels cmdset 3 "b) Patients with fatigue, without alarm symptoms", modify



/*In patients with no alarm symptoms - with/ without anaemia*/

local table_row 4
foreach symptom in 400 500 {

	table () (male) if symp_3mb_1ma_300 == 0 & symp_3mb_1ma_`symptom' == 1, ///
		stat(sum symp_3mb_1ma_100) ///
		command(r(iqr): iqr_prog age_idate) ///
		nototal name(Tab2) append	

	frame symptom_labels: local symp_label : label (symptom_number) `symptom'		/* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row
}

collect label levels cmdset 4 "With anaemia", modify
collect label levels cmdset 5 "c) Patients with fatigue, without alarm symptoms or anaemia", modify


/* In patients with no alarm symptoms and no anaemia */

*Global macro for 'any non alarm or each non alarm symptom'
global vague "600 700 1 2 7 12 15 17 18 19 20 21 22 36 37 38 39 40 43 44 45"

local table_row 6
foreach symptom of global vague {
	table () (male) if symp_3mb_1ma_500 == 1 & symp_3mb_1ma_`symptom' == 1, ///
		stat(sum symp_3mb_1ma_100) ///
		command(r(iqr): iqr_prog age_idate) ///
		nototal name(Tab2) append		

	frame symptom_labels: local symp_label : label (symptom_number) 		`symptom' 
	/* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row

}

collect label levels cmdset 7 "Without vague symptoms (i.e. fatigue only)", modify


*Apply formatting
common_formatting
table2

*Export to word
putdocx pagebreak
putdocx paragraph
putdocx text ("Cohort size and age characteristics of patients with fatigue, with each co-occurring symptom, for a) all fatigued patients b) all fatigued patients with no alarm symptoms, and c) fatigued patients with no alarm symptoms or anaemia")
putdocx collect

*Wipe temp file
use `temp2', clear


/******************************************************************************/
**# Figure. Cancer risk

*Change frames
frame change raw_data_1
collect clear

*Check - should be xxx men without alarm symptoms/ anaemia, with abdominal bloating (no. 2)
egen count_check = count(epatid) if symp_3mb_1ma_500 & male & symp_3mb_1ma_2
assert count_check== 308  if symp_3mb_1ma_500 & male & symp_3mb_1ma_2
drop count_check

/* Produce Figure 3 - %s and CIs for cancer given each non-spec symptom */
frame figure3 {
	clear
	set obs 64
	gen male = .
	gen symptom = .
	gen label = ""
	gen prop = .
	gen lb = .
	gen ub = .
	gen count = .
	gen high = .
}

/* Populate preparatory dataset - patients with no alarm symptom or anaemia*/
local row = 1
forval male = 0/1 {
	foreach symptom of global vague {

		frame symptom_labels: local symp_label : label (symptom_number) `symptom' ///
			/* as ordered by symptom */

		capture frame raw_data_1: ci proportions cancer_9mo ///
			if symp_3mb_1ma_`symptom' & symp_3mb_1ma_500 == 1 & male == `male', wilson

		frame figure3 {
			replace male = `male' 				in `row'
			replace symptom = `symptom' 		in `row'
			replace label = "`symp_label'" 		in `row'
			replace prop = r(proportion) 		in `row'
			replace lb   = r(lb) 				in `row'
			replace ub   = r(ub) 				in `row'
			replace count = r(N)				in `row'
		}
		local ++row
	}
}

/* Populate preparatory dataset - patients with no alarm symptom - with vs iwthout anaemia */
local row = 43
forval male = 0/1 {
	foreach symptom in 400 500 {

		frame symptom_labels: local symp_label : label (symptom_number) `symptom' ///
			/* as ordered by symptom */

		capture frame raw_data_1: ci proportions cancer_9mo ///
			if symp_3mb_1ma_`symptom' & symp_3mb_1ma_300 == 0 & male == `male', wilson

		frame figure3 {
			replace male = `male' 				in `row'
			replace symptom = `symptom' 		in `row'
			replace label = "`symp_label'" 		in `row'
			replace prop = r(proportion) 		in `row'
			replace lb   = r(lb) 				in `row'
			replace ub   = r(ub) 				in `row'
			replace count = r(N)				in `row'
		}
		local ++row
	}
}


/* Populate preparatory dataset - all patients - with vs iwthout alarm symptoms */
local row = 47
forval male = 0/1 {
	foreach symptom in 100 300 301 {

		frame symptom_labels: local symp_label : label (symptom_number) `symptom' ///
			/* as ordered by symptom */

		capture frame raw_data_1: ci proportions cancer_9mo ///
			if symp_3mb_1ma_`symptom' & male == `male', wilson

		frame figure3 {
			replace male = `male' 				in `row'
			replace symptom = `symptom' 		in `row'
			replace label = "`symp_label'" 		in `row'
			replace prop = r(proportion) 		in `row'
			replace lb   = r(lb) 				in `row'
			replace ub   = r(ub) 				in `row'
			replace count = r(N)				in `row'
		}
		local ++row
	}
}

frame figure3 {
	*Drop symptoms with wide CIs - pelvic pain 
	drop if symptom == 20

	*Replace 0-1 with %s
    replace prop  = prop * 100
	replace lb = lb * 100
	replace ub = ub * 100
}

*Order symptoms by cancer risk
frame figure3 {
	gen prop_rank = prop if !inlist(symptom, 100, 300, 301, 400, 500, 600, 700) 
	bysort male (prop_rank): egen symptom_order =rank(prop_rank), unique 

	replace symptom_order = symptom_order - 1 if male == 1

	replace symptom_order = 33 if symptom == 100

	replace symptom_order = 30 if symptom == 300
	replace symptom_order = 29 if symptom == 301

	replace symptom_order = 26 if symptom == 400
	replace symptom_order = 25 if symptom == 500

	replace symptom_order = 22 if symptom == 600
	replace symptom_order = 21 if symptom == 700
}

*Create graph
frame figure3 {
	label define male 0 "Women" 1 "Men", replace
	label values male male
	replace label = "Without anaemia" if label == "Without alarm symptoms or anaemia"
	replace label = "All patients" if label == "All fatigued patients"

	replace high = ub > 9
}

frame figure3 {
	*Create subcohort titles

	replace male = 1 if _n == 51 | _n == 52 | _n == 53 | _n == 54 | _n == 55
	replace male = 0 if _n == 56 | _n == 57 | _n == 58 | _n == 59 | _n == 60

	replace symptom_order = 34 if inlist(_n, 51, 56)
	replace label = "Fatigue" if inlist(_n, 51, 56)

	replace symptom_order = 31 if inlist(_n, 52, 57)
	replace label = "Fatigue +/- alarm symptoms" if inlist(_n, 52, 57)

	replace symptom_order = 27 if inlist(_n, 53, 58)
	replace label = "Fatigue without alarm symptoms +/- anaemia" if inlist(_n, 53, 58)

	replace symptom_order = 23 if inlist(_n, 54, 59)
	replace label = "Fatigue without alarm symptoms or anaemia +/- vague symptoms" if inlist(_n, 54, 59)

	replace symptom_order = 19 if inlist(_n, 55, 60)
	replace label = "Fatigue without alarm symptoms or anaemia + each vague symptom" if inlist(_n, 55, 60)

	gen subheading = 0 if inlist(_n, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60)
	gen subheading_lab_b = "{bf:" + label + "}" if inlist(_n, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60)
}


*Gen percent/ N labels
frame figure3 {
	gen lab = string(prop,"%03.1f") +" (" + string(lb,"%03.1f") + "-" + string(ub,"%03.1f") + "), n=" + string(count,"%7.0fc") if subheading != 0
	gen pos = 13
}

*Graph
frame figure3 {
	#delimit ;
	twoway	(scatter  symptom_order prop, msymb(o) mcolor(gs0) )
			(rspike lb ub symptom_order, lc(gs0) horizontal)
			(
				scatter symptom_order ub if !high
					, 	msymb(none) 
						mlab(label) 
						mlabc(gs0) 
						mlabp(3) 
						mlabsize(vsmall) 
			)
			(
				scatter symptom_order lb if  high
					, 	msymb(none) 
						mlab(label) 
						mlabc(gs0) 
						mlabp(9) 
						mlabsize(vsmall) 
			)
			(
				scatter symptom_order subheading
					, 	msymb(none) 
						mlab(subheading_lab_b) 
						mlabc(gs0) 
						mlabp(3) 
						mlabstyle(key_label) 
						mlabsize(vsmall)
			)
			(
				scatter symptom_order pos
					,  	mlab(lab) 
						mlabpos(3) 
						msymb(none) 
						mlabc(gs0) 
						mlabsize(vsmall)
			)
			,	by(male, note("") legend(off))  
				subtitle(, fcolor(gs0) color(gs16) pos(11))
				ytitle("")
				ylabel(none)
				ysc(r(0 5))
				xtitle("Patients developing cancer, as a proportion (%) of each subcohort", size(small))
				xsc(r(0 20))
				xlabel(0 "0" 3(3)12, format("%01.0f") grid)
				plotregion(margin(l=0))	
				yline(31.5, lcolor(black))
				yline(27.5, lcolor(black))
				yline(23.5, lcolor(black))
				yline(19.5, lcolor(black))
				name(Fig3, replace)
				;
	#delimit cr

	graph export Graphs/Fig3.png, width(1000) replace
}


*Export to word
putdocx pagebreak
putdocx paragraph
putdocx text ("Nine-month cancer risk in patients with fatigue and no alarm symptom/ anaemia, by presence of each co-occurring vague symptom (%)")
putdocx paragraph
putdocx image "Graphs/Fig3.png", width(12.8cm) height(9.3cm) linebreak(1)


/******************************************************************************/
**# Appendix table. Cohort sizes by time window

*Change frames
frame change raw_data_full

*Set up temp file
tempfile temp2
save `temp2'

keep epatid male cancer_9mo ///
	symp_0mb_1ma_* test_ab_0mb_1ma_* ///
	symp_3mb_1ma_* test_ab_3mb_1ma_* ///
	symp_6mb_1ma_* test_ab_6mb_1ma_* ///
	symp_9mb_1ma_* test_ab_9mb_1ma_* ///
	symp_12mb_1ma_* test_ab_12mb_1ma_*

compress

*Turn 0-1 vars into 0-100 for % generation from means
foreach var of varlist symp_0mb_1ma_* test_ab_0mb_1ma_* ///
	symp_3mb_1ma_* test_ab_3mb_1ma_* ///
	symp_6mb_1ma_* test_ab_6mb_1ma_* ///
	symp_9mb_1ma_* test_ab_9mb_1ma_* ///
	symp_12mb_1ma_* test_ab_12mb_1ma_* 	{
	gen `var'_p = `var' * 100
}

collect clear

*Create table rows
*All figs are % of all fatigued patients

/* Total - using a little fudge */
table (), stat(sum symp_0mb_1ma_100 symp_3mb_1ma_100 symp_6mb_1ma_100 symp_9mb_1ma_100 symp_12mb_1ma_100) nototal name(app4)
collect label levels cmdset 1 "All patients with fatigue", modify


*TOtal + alarm smptoms
global sa_symps "300 400 600 3 4 5 6 9 10 11 13 14 16 30 31 32 33 34 35 1 2 7 12 15 17 18 19 20 21 22 36 37 38 39 40 43 44 45"

local table_row 2
foreach symptom of global sa_symps   {
	/* Any symptoms */
	table (), stat(sum symp_0mb_1ma_`symptom' symp_3mb_1ma_`symptom' ///
		symp_6mb_1ma_`symptom' symp_9mb_1ma_`symptom' symp_12mb_1ma_`symptom') ///
		stat(mean symp_0mb_1ma_`symptom'_p symp_3mb_1ma_`symptom'_p ///
		symp_6mb_1ma_`symptom'_p symp_9mb_1ma_`symptom'_p symp_12mb_1ma_`symptom'_p) ///
		nototal name(app4) append

	frame symptom_labels: local symp_label : label (symptom_number) `symptom' /* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row
}

*Apply formatting
common_formatting
app4

*Wipe temp file
use `temp2', clear

*Export to word
putdocx pagebreak
putdocx paragraph
putdocx text ("Proportion (%) of patients with fatigue who had a co-occurring symptom*, by time window used to define co-occurrence**")
putdocx collect


/******************************************************************************/
**# Table. Cancer risk using 3 month time window 

*Set up temp file
tempfile temp2
save `temp2'

collect clear

/*All patients*/
table () (male) if  symp_3mb_1ma_100, ///
	stat(sum symp_3mb_1ma_100) ///
	stat(sum cancer_9mo) ///
	command(r(mean): prop100 cancer_9mo) ///
	command(r(ci): ci_prop cancer_9mo) ///
	nototal name(app4) append

foreach symptom in 100 {
	frame symptom_labels: local symp_label : label (symptom_number) `symptom'
	collect label levels cmdset 1 "`symp_label'", modify
}	

collect label levels cmdset 1 "a) All patients with fatigue", modify


/*All patients - with/ without any symptom/ any alarm symptom/ each alarm symptom*/
local table_row 2
global alarm "300 3 4 5 6 9 10 11 13 14 16 30 31 32 33 34 35 301"
foreach symptom of global alarm  {
	table () (male) if  symp_3mb_1ma_`symptom', ///
		stat(sum symp_3mb_1ma_`symptom') ///
		stat(sum cancer_9mo) ///
		command(r(mean): prop100 cancer_9mo) ///
		command(r(ci): ci_prop cancer_9mo) ///
		nototal name(app4) append

	frame symptom_labels: local symp_label : label (symptom_number) `symptom' /* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row
}

collect label levels cmdset 19 "b) Patients with fatigue without alarm symptoms", modify


/* In patients with no alarm symptoms - with/ without anaemia*/
local table_row 20
foreach symptom in 400 500 {
	table () (male) if symp_3mb_1ma_300 == 0 & symp_3mb_1ma_`symptom', ///
		stat(sum symp_3mb_1ma_`symptom') ///
		stat(sum cancer_9mo) ///
		command(r(mean): prop100 cancer_9mo) ///
		command(r(ci): ci_prop cancer_9mo) ///
		nototal name(app4) append

	frame symptom_labels: local symp_label : label (symptom_number) `symptom' /* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row
}

collect label levels cmdset 21 "c) Patients with fatigue without alarm symptoms or anaemia", modify


/* In patients with no alarm symptoms and no anaemia - each symptom*/
*Problem is here with "no non alarm symptom"
local table_row 22
foreach symptom of global vague  {
	table () (male) if symp_3mb_1ma_500 == 1 &  symp_3mb_1ma_`symptom', ///
		stat(sum symp_3mb_1ma_`symptom') ///
		stat(sum cancer_9mo) ///
		command(r(mean): prop100 cancer_9mo) ///
		command(r(ci): ci_prop cancer_9mo) ///
		nototal name(app4) append

	frame symptom_labels: local symp_label : label (symptom_number) `symptom' /* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row
}

*Recode var for new table layout
collect recode var symp_3mb_1ma_100 = symp
foreach symptom of global allsymp700  {
	collect recode var symp_3mb_1ma_`symptom' = symp
}

*Apply formatting
common_formatting
app5

*Wipe temp file
use `temp2', clear

*Export to word
putdocx pagebreak
putdocx paragraph
putdocx text ("Nine-month cancer risk (%) for patients with fatigue who had a co-occurring symptom 3 months before to 1 month after the first fatigue presentation. a) all patients with fatigue, b) patients with fatigue without alarm symptoms, and c) patients with fatigue without alarm symptoms or anaemia.")
putdocx collect


/******************************************************************************/
**# Table. Cancer risk using 12 month time window vs 3 month

*Set up temp file
tempfile temp2
save `temp2'

collect clear

/*All patients*/
table () (male) if  symp_12mb_1ma_100, ///
	stat(sum symp_12mb_1ma_100) ///
	stat(sum cancer_9mo) ///
	command(r(mean): prop100 cancer_9mo) ///
	command(r(ci): ci_prop cancer_9mo) ///
	nototal name(app4) append
	
foreach symptom in 100 {
	frame symptom_labels: local symp_label : label (symptom_number) `symptom'
	collect label levels cmdset 1 "`symp_label'", modify
}	

collect label levels cmdset 1 "a) All patients with fatigue", modify


/*All patients - with/ without all symptoms/ alarm symptoms*/
local table_row 2
foreach symptom of global alarm  {
	table () (male) if  symp_12mb_1ma_`symptom', ///
		stat(sum symp_12mb_1ma_`symptom') ///
		stat(sum cancer_9mo) ///
		command(r(mean): prop100 cancer_9mo) ///
		command(r(ci): ci_prop cancer_9mo) ///
		nototal name(app4) append

	frame symptom_labels: local symp_label : label (symptom_number) `symptom' /* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row
}

collect label levels cmdset 19 "b) Patients with fatigue without alarm symptoms", modify


/* In patients with no alarm symptoms - with/ without anaemia*/
local table_row 20
foreach symptom in 400 500 {
	table () (male) if symp_12mb_1ma_300 == 0 & symp_12mb_1ma_`symptom', ///
		stat(sum symp_12mb_1ma_`symptom') ///
		stat(sum cancer_9mo) ///
		command(r(mean): prop100 cancer_9mo) ///
		command(r(ci): ci_prop cancer_9mo) ///
		nototal name(app4) append

	frame symptom_labels: local symp_label : label (symptom_number) `symptom' /* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row
}

collect label levels cmdset 21 "c) Patients with fatigue without alarm symptoms or anaemia", modify


/* In patients with no alarm symptoms and no anaemia - each symptom*/
local table_row 22
foreach symptom of global vague  {
	table () (male) if symp_12mb_1ma_500 == 1 &  symp_12mb_1ma_`symptom', ///
		stat(sum symp_12mb_1ma_`symptom') ///
		stat(sum cancer_9mo) ///
		command(r(mean): prop100 cancer_9mo) ///
		command(r(ci): ci_prop cancer_9mo) ///
		nototal name(app4) append

	frame symptom_labels: local symp_label : label (symptom_number) `symptom' /* as ordered by symptom */

	collect label levels cmdset `table_row' "`symp_label'", modify
	local ++table_row
}

*Recode var for new table layout
collect recode var symp_12mb_1ma_100 = symp
foreach symptom of global allsymp700  {
	collect recode var symp_12mb_1ma_`symptom' = symp
}

*Apply formatting
common_formatting
app5

*Wipe temp file
use `temp2', clear

*Export to word
putdocx pagebreak
putdocx paragraph
putdocx text ("Nine-month cancer risk (%) for patients with fatigue who had a co-occurring symptom 12 months before to 1 month after the first fatigue presentation. a) all patients with fatigue, b) patients with fatigue without alarm symptoms, and c) patients with fatigue without alarm symptoms or anaemia.")
putdocx collect


/************************************************/
*Save word file
local todaydate: display %tdCCYY-NN-DD =daily("`c(current_date)'","DMY")
putdocx save autotables_`todaydate'.docx, replace

