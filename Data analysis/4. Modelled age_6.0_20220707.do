/******************************************************************************/
*4. Modelled age-specific estimates of risk
/******************************************************************************/

clear

/*****************************************************************************/
**# Frame setup and handling

frame change default

*Drop frames
foreach newframe in symptom_labels raw_data_2 pop_est model_data predict1 onerow_model symptom_anaemia  model4 age_predictions_vague age_predictions_anaemia age_thresholds {
	cap frame `newframe': clear
	cap frame drop `newframe'
}

*Create selected frames
foreach newframe in symptom_labels raw_data_2 pop_est model_data {
	frame create `newframe'
}

*Load data frames*/

** Symptom lookup
frame change symptom_labels
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
use "symptom_lookup", clear

** Population estimates
frame change pop_est
cd "S:\ECHO_IHI_CPRD\Data\Becky\Fatigue other symptoms\"
use "genpop_1.0_20052021.dta", clear

*Data 
frame change raw_data_2
use "Symptoms_ppvs_2_c", clear

keep epatid male age* cancer_9mo symp_3mb_1ma_*   
compress

*Change to export folder
cd "S:\ECHO_IHI_CPRD\Becky\Fatigue other symptoms\Table exports\"


/******************************************************************************/
/*Set up formatting*/

/* Set base graph scheme */
set scheme s1color

*set line size otherwise tables are too wide below
set linesize 255

/******************************************************************************/
**# Create dataset for observed %s

*Create separate dataset for each cohort, then append together

*Just patients with no alarm symptom with/ without anaemia*
foreach i in 400 401 {
	cap frame symptom_`i': clear
	cap frame drop symptom_`i'
	frame raw_data_2: frame put epatid cancer_9mo male age*  symp_3mb_1ma_`i' if symp_3mb_1ma_300 == 0, into(symptom_`i')
}

foreach i in 400 401 {
	frame change symptom_`i'
	gen symptom_number = `i' if symp_3mb_1ma_`i'
	drop symp_3mb_1ma_`i'
	save "symptom_`i'", replace
}

*Just patients with no alarm symptom or anaemia - with / withotu vague symptoms*/
* global macro for 'any vague or each vague symptom', excl pelvic pain & night sweats (because small samples)
global predict_vague "600 700 1 2 7 15 17 18 19 21 22 36 37 38 39 40 43 44 45"
foreach i of global predict_vague {
	cap frame symptom_`i': clear
	cap frame drop symptom_`i'
	frame raw_data_2: frame put epatid cancer_9mo male age* symp_3mb_1ma_`i' if symp_3mb_1ma_500 == 1 & symp_3mb_1ma_`i' == 1, into(symptom_`i')
}

foreach i of global predict_vague {
	frame change symptom_`i' 
	gen symptom_number = `i' if symp_3mb_1ma_`i'
	drop symp_3mb_1ma_`i'
	save "symptom_`i'", replace
}

*Append separate datasets for each symptom into one dataset
frame model_data: use "symptom_400"
foreach i in 401 600 700 1 2 7 15 17 18 19 21 22 36 37 38 39 40 43 44 45 {
	frame model_data: append using "symptom_`i'"
}

*Symptom labels
global predict_groups "400 401 600 700 1 2 7 15 17 18 19 21 22 36 37 38 39 40 43 44 45"

frame model_data {
	foreach symptom of global predict_groups {
		frame symptom_labels: local symp_label : label (symptom_number) `symptom'
		label define labelval `symptom' "`symp_label'", modify
	}		
	label values symptom_number labelval
	compress

	*Other labels	
	label var symptom_number "co-occurring symptom"
}


/******************************************************************************/
**# Create empty frame for prediction results
frame model_data: frame put male age_idate symptom_number, into(predict1)
frame change predict1

frame predict1 {
	duplicates drop
	fillin male age_idate symptom_number
	gen agegroup_10yr = floor(age_idate/10)*10
	gen agegroup_5yr = floor(age_idate/5)*5

	foreach i of global predict_groups {
		gen symp_3mb_1ma_`i' = 0
		replace symp_3mb_1ma_`i' = 1 if symptom_number == `i'
	}

	*Rename any vague symptom as it's coming from a differnet model with different var name
	rename symp_3mb_1ma_600 symp_3mb_1ma600
	rename symp_3mb_1ma_400 symp_3mb_1ma400
	rename symp_3mb_1ma_401 symp_3mb_1ma401

	tab age_idate
	tab agegroup_10yr
	tab symptom_number 

	label var agegroup_10yr "Age at entry, 10-year bands"
	label var agegroup_5yr "Age at entry, 5-year bands"

	order male symptom_number age_idate agegroup_10yr
	sort male symptom_number  age_idate agegroup_10yr
}


/* *****************************************/
**# Create dataset for poisson model

*Just patients with no alarm symptom with/ without anaemia*/
frame raw_data_2: frame put epatid cancer_9mo male age*  symp_3mb_1ma_400 if symp_3mb_1ma_300 == 0, into(symptom_anaemia)
save "symptom_anaemia", replace

*Just patients with no alarm symptom or anaemia - with/ without a) any vague symptom and b) each vague symptom 
frame raw_data_2: frame put epatid cancer_9mo male age* symp_3mb_1ma_* if symp_3mb_1ma_500 == 1, into(onerow_model)


frame onerow_model {

	*Drop alarm symptoms, blood tests, no vague symptoms, multi combos
	foreach i in 3 4 5 6 9 8 10 11 13 14 16 30 31 32 33 34 35 23 24 25 26 27 28 29    100 300 500 700 count 2combos {
		drop symp_3mb_1ma_`i'
	}

	*Drop rare symptoms (pelvic pain & night sweats)
	frame onerow_model: drop  symp_3mb_1ma_12 symp_3mb_1ma_20

	*Rename anaemia/ any vague symptom variables
	*Because these are run in different models to the rest of the vague symptoms
    rename symp_3mb_1ma_600 symp_3mb_1ma600
	rename symp_3mb_1ma_301 symp_3mb_1ma301
	rename symp_3mb_1ma_400 symp_3mb_1ma400
	rename symp_3mb_1ma_401 symp_3mb_1ma401
}


/* *****************************************/
**# Run anaemia model

collect clear
collect create models_anaemia

*Create age splines

*In model dataset
frame symptom_anaemia {

	rename symp_3mb_1ma_400 symp_3mb_1ma400
	gen age_c = (age_idate-65)/10

	mkspline age_spl_m_an = age_c if male == 1 , cubic nknots(5) displayknots
	local age_knot1_m_an = r(knots)["age_c","knot1"]
	local age_knot2_m_an = r(knots)["age_c","knot2"]
	local age_knot3_m_an = r(knots)["age_c","knot3"]
	local age_knot4_m_an = r(knots)["age_c","knot4"]
	local age_knot5_m_an = r(knots)["age_c","knot5"]

	mkspline age_spl_f_an = age_c if male == 0 , cubic nknots(5) displayknots
	local age_knot1_f_an = r(knots)["age_c","knot1"]
	local age_knot2_f_an = r(knots)["age_c","knot2"]
	local age_knot3_f_an = r(knots)["age_c","knot3"]
	local age_knot4_f_an = r(knots)["age_c","knot4"]
	local age_knot5_f_an = r(knots)["age_c","knot5"]
}

*In prediction frame
frame predict1 {
	gen age_c = (age_idate-65)/10

	mkspline age_spl_m_an = age_c if male == 1, cubic knots(`age_knot1_m_an' `age_knot2_m_an' `age_knot3_m_an' `age_knot4_m_an' `age_knot5_m_an')

	mkspline age_spl_f_an = age_c if male == 0, cubic knots(`age_knot1_f_an' `age_knot2_f_an' `age_knot3_f_an' `age_knot4_f_an' `age_knot5_f_an')
}


*Run models

*Men
frame symptom_anaemia {
    collect _r_b _r_ci, name(models_anaemia) tag(model[(1)]): poisson cancer_9mo i.symp_3mb_1ma400  c.age_spl_m_an* if male, vce(robust) irr nrtolerance(1e-12) tolerance(1e-9)		
	estimates store model4_m_anaemia
}

* predict linear predictor and then transform to IR
*NB. 400 = with anaemia yes/ no and 401 = without anemia yes/ no. So below includes fudge to create predictions for patients without anaemia, by creating predictions when symptom_number == 401 (in these rows, symp_3mb_1ma_400 == 0)
frame predict1 {
	predictnl pr_model4 = predict(xb) if male == 1 & symptom_number == 400 | symptom_number == 401, ci(pr_lb_model4 pr_ub_model4) force
	foreach thing in pr_model4 pr_lb_model4 pr_ub_model4 {
		replace `thing' = exp(`thing')
	}
}

*Women
frame symptom_anaemia {
    collect _r_b _r_ci, name(models_anaemia) tag(model[(2)]): poisson cancer_9mo i.symp_3mb_1ma400  c.age_spl_f_an* if !male, vce(robust) irr nrtolerance(1e-12)	
	estimates store model4_f_anaemia
}

* predict linear predictor and then transform to IR
frame predict1 {
	predictnl pr_model4_temp = predict(xb) if male == 0 & symptom_number == 400 | symptom_number == 401 , ci(pr_lb_model4_temp pr_ub_model4_temp) force
	foreach thing in pr_model4 pr_lb_model4 pr_ub_model4 {
		replace `thing'_temp = exp(`thing'_temp)
		replace `thing' = `thing'_temp if `thing' == .
		drop `thing'_temp
	}
}


*Table of risk ratio results for appendix
collect layout (colname#result) (model), name(models_anaemia)
collect label levels symp_3mb_1ma400 1 "Anaemia", modify

*Label model
collect label levels model (1) "Men" (2) "Women", modify
collect style header model, level(label) title(hide)

*Format cells
collect style showbase off
collect style cell, nformat(%5.2f)
collect style cell result[_r_ci], sformat("(%s)")
collect preview

collect save, replace


/* *****************************************/
**# Run any vague symptom model

collect clear
collect create models_all

*Check correct number of patients in onerow_model (just patietns without alarm symptoms or anaemia)
frame onerow_model {
	egen count_check = count(epatid) if male & symp_3mb_1ma_2
	assert count_check==308  if male & symp_3mb_1ma_2 //  men with abdominal bloating (no alarm symptoms/ anaemia)
	drop count_check
	egen count_check = count(epatid) if male 
	assert count_check==78471  if male // men overall (no alarm symptoms/ anaemia)
	drop count_check
}

*Create age splines

*In model dataset
frame onerow_model {
	gen age_c = (age_idate-65)/10

	mkspline age_spl_m = age_c if male == 1 , cubic nknots(5) displayknots
	local age_knot1_m = r(knots)["age_c","knot1"]
	local age_knot2_m = r(knots)["age_c","knot2"]
	local age_knot3_m = r(knots)["age_c","knot3"]
	local age_knot4_m = r(knots)["age_c","knot4"]
	local age_knot5_m = r(knots)["age_c","knot5"]

	mkspline age_spl_f = age_c if male == 0 , cubic nknots(5) displayknots
	local age_knot1_f = r(knots)["age_c","knot1"]
	local age_knot2_f = r(knots)["age_c","knot2"]
	local age_knot3_f = r(knots)["age_c","knot3"]
	local age_knot4_f = r(knots)["age_c","knot4"]
	local age_knot5_f = r(knots)["age_c","knot5"]
}

*In prediction frame
frame predict1 {

	mkspline age_spl_m = age_c if male == 1, cubic knots(`age_knot1_m' `age_knot2_m' `age_knot3_m' `age_knot4_m' `age_knot5_m')

	mkspline age_spl_f = age_c if male == 0, cubic knots(`age_knot1_f' `age_knot2_f' `age_knot3_f' `age_knot4_f' `age_knot5_f')

}

*Run models
*Men
frame onerow_model {
	collect _r_b _r_ci, name(models_all) tag(model[(1)]): poisson cancer_9mo i.symp_3mb_1ma600  c.age_spl_m* if male == 1, vce(robust) irr	 nrtolerance(1e-12)	
	estimates store model4_m_all
}

* predict linear predictor and then transform to IR
*Only do predictions for men and symptoms we just modelled 
frame predict1 {
	predictnl pr_model4_temp = predict(xb) if male == 1 & symptom_number == 600, ci(pr_lb_model4_temp pr_ub_model4_temp) force
	foreach thing in pr_model4 pr_lb_model4 pr_ub_model4 {
		replace `thing'_temp = exp(`thing'_temp)
		replace `thing' = `thing'_temp if `thing' == .
		drop `thing'_temp
	}
}


*Women
frame onerow_model {
	collect _r_b _r_ci, name(models_all) tag(model[(2)]): poisson cancer_9mo i.symp_3mb_1ma600  c.age_spl_f* if male == 0, vce(robust) irr nrtolerance(1e-12)	
	estimates store model4_f_all
}

* predict linear predictor and then transform to IR
*Only do predictions for women and symptoms we just modelled 
frame predict1 {
	predictnl pr_model4_temp = predict(xb) if male == 0 & symptom_number == 600, ci(pr_lb_model4_temp pr_ub_model4_temp) force
	foreach thing in pr_model4 pr_lb_model4 pr_ub_model4 {
		replace `thing'_temp = exp(`thing'_temp)
		replace `thing' = `thing'_temp if `thing' == .
		drop `thing'_temp
	}
}

*Table of risk ratio results for appendix
collect layout (colname#result) (model), name(models_all)
collect label levels symp_3mb_1ma600 1 "Any vague symptom", modify

*Label model
collect label levels model (1) "Men" (2) "Women", modify
collect style header model, level(label) title(hide)

*Format cells
collect style showbase off
collect style cell, nformat(%5.2f)
collect style cell result[_r_ci], sformat("(%s)")
collect preview

collect save, replace


/* *****************************************/
**# Run each vague symptom model

collect clear
collect create models

*Run models
*Male
frame onerow_model {
	collect _r_b _r_ci, name(models) tag(model[(1)]): poisson cancer_9mo i.symp_3mb_1ma_*  c.age_spl_m* if male == 1, vce(robust) irr	 nrtolerance(1e-12)	
	estimates store model4_m
}

* predict linear predictor and then transform to IR
*Only do predictions for men and symptoms we just modelled 
frame predict1 {
	predictnl pr_model4_temp = predict(xb) if male == 1 & !inlist(symptom_number,12, 20, 301, 400, 401, 600), ci(pr_lb_model4_temp pr_ub_model4_temp) force
	foreach thing in pr_model4 pr_lb_model4 pr_ub_model4 {
		replace `thing'_temp = exp(`thing'_temp)
		replace `thing' = `thing'_temp if `thing' == .
		drop `thing'_temp
	}
}

*Female
frame onerow_model {
	collect _r_b _r_ci, name(models) tag(model[(2)]): poisson cancer_9mo i.symp_3mb_1ma_*  c.age_spl_f* if male == 0, vce(robust) irr nrtolerance(1e-12)	
	estimates store model4_f
}

* predict linear predictor and then transform to IR
*Only do predictions for women and symptoms we just modelled 
frame predict1 {
	predictnl pr_model4_temp = predict(xb) if male == 0 & !inlist(symptom_number,12, 20, 38, 301, 400, 401, 600), ci(pr_lb_model4_temp pr_ub_model4_temp) force
	foreach thing in pr_model4 pr_lb_model4 pr_ub_model4 {
		replace `thing'_temp = exp(`thing'_temp)
		replace `thing' = `thing'_temp if `thing' == .
		drop `thing'_temp
	}
}


*Table of risk ratio results for appendix
collect layout (colname#result) (model), name(models)

*Label symptoms
foreach symptom of global predict_groups {
	frame symptom_labels: local symp_label : label (symptom_number) `symptom'
	collect label levels symp_3mb_1ma_`symptom' 1 "`symp_label'", modify
}		

*Label model
collect label levels model (1) "Men" (2) "Women", modify
collect style header model, level(label) title(hide)

*Format cells
collect style showbase off
collect style cell, nformat(%5.2f)
collect style cell result[_r_ci], sformat("(%s)")
collect preview

collect save, replace


/******************************************************************************/
**# Format predictions

frame predict1 {

	*x 100 into %s
	foreach thing in pr_model4 pr_lb_model4 pr_ub_model4 {
		replace `thing' = `thing'*100
	}

	* Add populatoin estimates*/
	*Pop estimates end at 85+, so create 5 year var with 85-99 group at end
	gen agegroup_5yr_85to99 = agegroup_5yr
	replace agegroup_5yr_85to99 = 85 if agegroup_5yr > 85

	frlink m:1 male agegroup_5yr_85to99, frame(pop_est) 
	frget denominator cases_9mo cancer_9mo_popest, from(pop_est)
	
	*Drop missing symptom numbers
	drop if symptom_number == .
	
	compress
}


/******************************************************************************/
**#  Graph: Estimates by symptom 

frame  predict1	{

	*Anaemia 

	*Male
	#delimit ;
	
	twoway	
		(rarea pr_lb_model4 pr_ub_model4 age_idate, color(green%20))
		(line pr_model4 age_idate, color(green) )  
		(line cancer_9mo_popest age_idate, color(gs0) lpattern(shortdash) )
		
		if male == 1 & inlist(symptom_number, 400, 401)
		
		, by(symptom_number)
		
		legend(order(2 "Fatigued patients" 3 "General population") cols(3) symxs(*.5))  
		xsc(r(30 99))  
		xlabel(30(10)90 99)  
		ylabel(0(1)10)
		yline(1, lcolor(yellow)) 
		yline(3, lcolor(orange))  
		yline(5, lcolor(red))
		
		name(results_bysymp_anaemia_m, replace)
	;
	#delimit cr
	
	graph export Graphs/results_bysymp_anaemia_m.png, width(1000) replace


	*Female
	#delimit ;
	
	twoway		
		(rarea pr_lb_model4 pr_ub_model4 age_idate, color(green%20)) 
		(line pr_model4 age_idate, color(green) )  
		(line cancer_9mo_popest age_idate, color(gs0) lpattern(shortdash) ) 
		
		if male == 0 & inlist(symptom_number, 400, 401) 
		
		, by(symptom_number) 
		
		legend(order(2 "Fatigued patients" 3 "General population") cols(3) symxs(*.5))  
		xsc(r(30 99))  
		xlabel(30(10)90 99)  
		ylabel(0(1)6)  
		yline(1, lcolor(yellow)) 
		yline(3, lcolor(orange))  
		yline(5, lcolor(red)) 
		
		name(results_bysymp_anaemia_f, replace)
	;
	#delimit cr
	
	graph export Graphs/results_bysymp_anaemia_f.png, width(1000) replace


	*Vague symptoms
	*Should not show: pelvic pain, night sweats, testicular pain (women)

	*Male
	#delimit ;
	
	twoway	
		(rarea pr_lb_model4 pr_ub_model4 age_idate, color(green%20)) 
		(line pr_model4 age_idate, color(green) )  
		(line cancer_9mo_popest age_idate, color(gs0) lpattern(shortdash) ) 
		
		if male == 1 & !inlist(symptom_number, 12, 20, 400, 401) 
		
		, by(symptom_number) 
		
		legend(order(2 "Fatigued patients" 3 "General population") cols(3) symxs(*.5))  
		xsc(r(30 99))  
		xlabel(30(10)90 99)  
		ylabel(0(5)20)  
		yline(1, lcolor(yellow)) 
		yline(3, lcolor(orange))  
		yline(5, lcolor(red)) 
		
		name(results_bysymp_vague_m, replace)
	;
	#delimit cr
	
	graph export Graphs/results_bysymp_vague_m.png, width(1000) replace

	*Female
	#delimit ;
	
	twoway	
		(rarea pr_lb_model4 pr_ub_model4 age_idate, color(green%20)) 
		(line pr_model4 age_idate, color(green) )  
		(line cancer_9mo_popest age_idate, color(gs0) lpattern(shortdash) )
		
		if male == 0 & !inlist(symptom_number, 12, 20, 38, 400, 401)
		
		, by(symptom_number)
		
		legend(order(2 "Fatigued patients" 3 "General population") cols(3) symxs(*.5)) 
		xsc(r(30 99)) 
		xlabel(30(10)90 99)  
		ylabel(0(1)7)  
		yline(1, lcolor(yellow)) 
		yline(3, lcolor(orange)) 
		yline(5, lcolor(red))
		name(results_bysymp_vague_f, replace)
	;
	#delimit cr
	
	graph export Graphs/results_bysymp_vague_f.png, width(1000) replace
}



/******************************************************************************/
**# Graph: Estimates by selected age

*Set up frame
frame predict1: frame put male age_idate symptom_number pr_model4 pr_lb_model4 pr_ub_model4 cancer_9mo_popest, into(model4)

frame model4 {


	*Drop small sample sizes
	drop if symptom_number == 12 | symptom_number == 20
	drop if symptom_number == 38 & male == 0

	*Gen rank of symptom frequency at each age
	gen prop_rank = pr_model4 if !inlist(symptom_number, 400, 401, 700, 600)
	bysort male age_idate (prop_rank): egen symptom_order =rank(prop_rank), unique 

	*order any and no vague so it is at the top of graph
	replace symptom_order = 26 if symptom_number == 401
	replace symptom_order = 25 if symptom_number == 400

	replace symptom_order = 22 if symptom_number == 700
	replace symptom_order = 21 if symptom_number == 600

	*Keep ages of interest
    keep if inlist(age_idate, 40, 50, 60, 70, 80, 90)

	*Var to position the labels
	gen high = .
	replace high = pr_ub_model4 > 12 & pr_ub_model4 < . & male == 1

	*Var to position pop est line
	gen symptom_order_pop = symptom_order
	replace symptom_order_pop = 0 if symptom_order_pop == 1
	replace symptom_order_pop = 28 if symptom_order_pop == 26

	*Create % and CI labels
	gen ci_lab = string(pr_model4,"%03.1f") + " (" + string(pr_lb_model4,"%03.1f") + "-" + string(pr_ub_model4,"%03.1f") + ")"
	gen pos = 13.5 if male == 1
	replace pos = 9 if male == 0


	*Fudge to create subcohort titles - men

	*Add more obs
	set obs 400

	*Allocate new obs to categories - gender, age groups
	replace male = 1 if _n >= 300 & _n <= 318
	replace age_idate = 40 if _n >= 301  & _n <= 303
	replace age_idate = 50 if _n >= 304 & _n <= 306
	replace age_idate = 60 if _n >= 307 & _n <= 309
	replace age_idate = 70 if _n >= 310 & _n <= 312
	replace age_idate = 80 if _n >= 313 & _n <= 315
	replace age_idate = 90 if _n >= 316 & _n <= 318

	*Label new obs with titles & placement on graph
	replace symptom_order = 27 if inlist(_n, 301, 304, 307, 310, 313, 316)
	gen label = "Fatigue without alarm symptoms +/- anaemia" if symptom_order == 27

	replace symptom_order = 23  if inlist(_n, 302, 305, 308, 311, 314, 317)
	replace label = "Fatigue without alarm symptoms or anaemia +/- vague symptoms" if symptom_order == 23

	replace symptom_order = 19 if inlist(_n, 303, 306, 309, 312, 315, 318)
	replace label = "Fatigue without alarm symptoms or anaemia + each vague symptom" if symptom_order == 19

	gen subheading = 0 if inlist(symptom_order, 19, 23, 27)
	gen subheading_lab_b = "{bf:" + label + "}" if inlist(symptom_order, 19, 23, 27)


	*Create graph

	*Men
	local labels_name msymb(none) mlab(symptom_number) mlabc(gs0) mlabsize(tiny) 
	local labels_numb msymb(none) mlab(ci_lab)         mlabc(gs0) mlabsize(tiny) 

	#delimit ;
	
	twoway	
		(scatter  symptom_order pr_model4 if male,
				msymb(o) mcolor(gs0) msize(vsmall))
				
		(rspike pr_lb_model4 pr_ub_model4 symptom_order if male,
				lc(gs0) horizontal lwidth(thin))
				
		(scatter symptom_order pr_ub_model4 if male & !high,
				`labels_name' mlabp(3))
				
		(scatter symptom_order pr_lb_model4 if male & high,
				`labels_name' mlabp(9))
				
		(scatter symptom_order pos if male &  !(age == 90 & high),
				`labels_numb' mlabp(3))
				
		(scatter symptom_order pos if male &    age == 90 & high,
				`labels_numb' mlabp(2))
				
		(scatter symptom_order subheading if male,
				msymb(none) mlab(subheading_lab_b) mlabc(gs0) mlabp(3) mlabstyle(key_label) mlabsize(tiny))
				
		(line symptom_order_pop cancer_9mo_popest if male,
				lcolor(green%40))

		, by(age_idate, note("") legend(off) rows(2))
		
		subtitle(, fcolor(gs0) color(gs16) pos(11) size(vsmall))
		ytitle("")
		ylabel(none)

		yline(23.7, lcolor(black) lwidth(thin))
		yline(19.7, lcolor(black) lwidth(thin))

		xtitle("Proportion (%) of men with fatigue without alarm symptoms/ anaemia developing cancer", size(tiny))
		ysc(r(0 5))
		xsc(r(0 17))
		xlabel(0 "0" 1(1)13, format("%01.0f") grid labsize(vsmall))
		plotregion(margin(0 0 0 0))		

		name(results_byage_allsymp_m, replace)
	;
	#delimit cr
	
	graph export Graphs/results_byage_allsymp_m.png, width(1000) replace


	*Fudge to create subcohort titles - women
	replace male = 0 if _n >= 300 & _n <= 318

	*Women
	local labels_name msymb(none) mlab(symptom_number) mlabc(gs0) mlabsize(tiny) 
	local labels_numb msymb(none) mlab(ci_lab)         mlabc(gs0) mlabsize(tiny) 

	#delimit ;
	
	twoway	
		(scatter  symptom_order pr_model4 if !male,
					msymb(o) mcolor(gs0) msize(vsmall))
					
		(rspike pr_lb_model4 pr_ub_model4 symptom_order if !male,
					lc(gs0) horizontal lwidth(thin))
					
		(scatter symptom_order pr_ub_model4 if !male & !high,
					`labels_name' mlabp(3))
					
		(scatter symptom_order pr_lb_model4 if !male & high,
					`labels_name' mlabp(9))
					
		(scatter symptom_order pos if !male & !(age == 90 & high),
					`labels_numb' mlabp(3))
					
		(scatter symptom_order pos if !male & age == 90 & high,
					`labels_numb' mlabp(2))
					
		(scatter symptom_order subheading if !male,
					msymb(none)	mlab(subheading_lab_b) mlabc(gs0) mlabp(3) 
					mlabstyle(key_label) mlabsize(tiny))
					
		(line symptom_order_pop cancer_9mo_popest if !male,
					lcolor(green%40))

		,	by(age_idate, note("") legend(off) rows(2)) 
		
		subtitle(, fcolor(gs0) color(gs16) pos(11) size(vsmall))
		ytitle("")
		ylabel(none)

		yline(23.7, lcolor(black) lwidth(thin))
		yline(19.7, lcolor(black) lwidth(thin))

		xtitle("Proportion (%) of women with fatigue without alarm symptoms/ anaemia developing cancer", size(tiny))
		ysc(r(0 5))
		xsc(r(0 11.5))
		xlabel(0 "0" 1(1)9, format("%01.0f") grid labsize(vsmall))
		plotregion(margin(0 0 0 0))		

		name(results_byage_allsymp_f, replace)
	;
	#delimit cr
	
	graph export Graphs/results_byage_allsymp_f.png, width(1000) replace
}


/**************************************************************/
**# Export all age specific predictions to excel

*Anaemia
*Output age specific predictions, by symptom
frame predict1: frame put male age_idate symptom_number cancer_9mo_popest pr_model4 pr_ub_model4 pr_lb_model4, into(age_predictions_anaemia)

frame age_predictions_anaemia {

	*Drop vars / obs not needed
	keep if inlist(symptom_number, 400, 401)

	*Reshape to wide
	reshape wide cancer_9mo_popest pr_model4 pr_ub_model4 pr_lb_model4 , i(age male) j(symptom)

	*Reformat pop est
	rename cancer_9mo_popest400 popest
	drop cancer_9mo_popest*

	*Label symptom vars
	frame symptom_labels: qui levelsof symptom_number, local(symptoms)

	qui foreach symptom in 400 401 {
		frame symptom_labels: local symp_desc : label (symptom_number) `symptom'
		label variable pr_model4`symptom' "`symp_desc' (%)"
		label variable pr_lb_model4`symptom' "`symp_desc' (Lower 95% CI)"
		label variable pr_ub_model4`symptom' "`symp_desc' (Upper 95% CI)"
	}
	
	label var age_idate "Year of age"
	label var popest "General popuation"
	
	sort male age_idate
	order male age_idate popest *400 *401

	*Output to excel - full appendix of age specific RRs
	export excel using "Results_rr_anaemia.xls", firstrow(varlabels) keepcellfmt replace
}

*Vague symtoms
frame predict1: frame put male age_idate symptom_number cancer_9mo_popest pr_model4 pr_ub_model4 pr_lb_model4, into(age_predictions_vague)


frame  age_predictions_vague {

	*Drop vars / obs not needed
	drop if inlist(symptom_number, 400, 401) | (symptom_number == 38 & !male)
	drop if symptom_number == .

	*Reshape to wide
	reshape wide cancer_9mo_popest pr_model4 pr_ub_model4 pr_lb_model4 , i(age male) j(symptom)

	*Reformat pop est
	rename cancer_9mo_popest1 popest
	drop cancer_9mo_popest*

	*Label symptom vars
	frame symptom_labels: qui levelsof symptom_number, local(symptoms)

	qui foreach symptom in 600 1 2 7 15 17 18 19 21 22 36 37 38 39 40 43 44 45 {
		frame symptom_labels: local symp_desc : label (symptom_number) `symptom'
		label variable pr_model4`symptom' "`symp_desc' (%)"
		label variable pr_lb_model4`symptom' "`symp_desc' (Lower 95% CI)"
		label variable pr_ub_model4`symptom' "`symp_desc' (Upper 95% CI)"
	}

	label var pr_model4700 "Without vague symptoms (%)"
	label var pr_lb_model4700 "Without vague symptoms (Lower 95% CI)"
	label var pr_ub_model4700 "Without vague symptoms (Upper 95% CI)"

	label var age_idate "Year of age"
	label var popest "General popuation"

	sort male age_idate
	order male age_idate popest *700 *600 *1 *2 *7 *15 *17 *18 *19 *21 *22 *36 *37 *38 *39 *40 *43 *44 *45

	*Output to excel - full appendix of age specific RRs
	export excel using "Results_rr_vaguesymptoms.xls", firstrow(varlabels) keepcellfmt replace

}


/**************************************************************/
**# Table 2. Ages when risk > 2, 3, 6%

frame predict1: frame put male age_idate symptom_number cancer_9mo_popest pr_model4 pr_ub_model4 pr_lb_model4, into(age_thresholds)

frame change age_thresholds

*Flag first age when % > 2, 3, 6

*2p
gen pr_model4_2p = pr_model4 if pr_model4 > 2 & pr_model4 < .
bysort male symptom_number   (age_idate): egen rank_2p =rank(pr_model4_2p), unique 

*3p
gen pr_model4_3p = pr_model4 if pr_model4 > 3 & pr_model4 < .
bysort male symptom_number   (age_idate): egen rank_3p =rank(pr_model4_3p), unique 

*6p
gen pr_model4_6p = pr_model4 if pr_model4 > 6 & pr_model4 < .
bysort male symptom_number   (age_idate): egen rank_6p =rank(pr_model4_6p), unique 

*Keep first ages over the thresholds
keep if rank_2p == 1 | rank_3p == 1 | rank_6p == 1

*Col for first ages
gen age_2p = .
replace age_2p = age_idate if rank_2p == 1

gen age_3p = .
replace age_3p = age_idate if rank_3p == 1

gen age_6p = .
replace age_6p = age_idate if rank_6p == 1

*Keep columns of interest
drop rank_2p rank_3p rank_6p age_idate cancer_9mo_popest *model4*

*One row per sex and symptom
collapse (mean) age*, by(male symptom_number)

*Reshape male/ females from long to wide
reshape wide age*, i(symptom_number) j(male)

*Drop anaemia
drop if symptom_number == 400 | symptom_number == 401

*Create string symptom variable
decode symptom_number, gen(symptom_desc)
drop symptom_number

*Rename vars
rename age_2p0 women_age_2p
rename age_3p0 women_age_3p
rename age_6p0 women_age_6p
rename age_2p1 men_age_2p
rename age_3p1 men_age_3p
rename age_6p1 men_age_6p

*Label vars
label var symptom_desc "Symptom"
label var women_age_2p "Women: >2%"
label var women_age_3p "Women: >3%"
label var women_age_6p "Women: >6%"
label var men_age_2p "Men: >2%"
label var men_age_3p "Men: >3%"
label var men_age_6p "Men: >6%"

*Sort rows
sort symptom_desc

*Order cols
order symptom_desc


/**************************************************************/
**# Export all other outputs to word

*Begin word doc
putdocx clear
putdocx begin


*Model estimates - all ages, by symptom - vague symptoms
putdocx paragraph
putdocx text ("Modelled nine-month cancer risk (%) in patients with fatigue and no alarm symptom/ anaemia. Risk for non-linear continuous age modelled using cubic splines.")

putdocx paragraph
putdocx text ("Males")
putdocx paragraph
putdocx image "Graphs/results_bysymp_vague_m.png", width(12.8cm) height(9.3cm) linebreak(1)

putdocx paragraph
putdocx text ("Females")
putdocx paragraph
putdocx image "Graphs/results_bysymp_vague_f.png", width(12.8cm) height(9.3cm) linebreak(1)

*Model estimates - all ages, by symptom - anaemia
putdocx paragraph
putdocx text ("Modelled nine-month cancer risk (%) in patients with fatigue and no alarm symptom; comparison of patients with and without anaemia. Risk for non-linear continuous age modelled using cubic splines.")

putdocx paragraph
putdocx text ("Males")
putdocx paragraph
putdocx image "Graphs/results_bysymp_anaemia_m.png", width(12.8cm) height(9.3cm) linebreak(1)

putdocx paragraph
putdocx text ("Females")
putdocx paragraph
putdocx image "Graphs/results_bysymp_anaemia_f.png", width(12.8cm) height(9.3cm) linebreak(1)



*Model estimates - symptoms, by selected ages 40, 50 60 etc - all symp (both vague and anaemia)
putdocx paragraph
putdocx text ("Modelled nine-month cancer risk (%) in a) patients with fatigue and no alarm symptom, b) patients with fatigue and no alarm symptom or anaemia. Risk for non-linear continuous age modelled using cubic splines.")

putdocx paragraph
putdocx text ("Males")
putdocx paragraph
putdocx image "Graphs/results_byage_allsymp_m.png", width(12.8cm) height(9.3cm) linebreak(1)

putdocx paragraph
putdocx text ("Females")
putdocx paragraph
putdocx image "Graphs/results_byage_allsymp_f.png", width(12.8cm) height(9.3cm) linebreak(1)



*Full appendix of age specific RRs (from collect command)
putdocx pagebreak
putdocx paragraph
putdocx text ("Risk ratios")

putdocx paragraph
putdocx text ("Each co-occurring vague symptom")
putdocx paragraph
collect clear
collect use models
putdocx collect

putdocx paragraph
putdocx text ("Any vague symptom")
putdocx paragraph
collect clear
collect use models_all
putdocx collect

putdocx paragraph
putdocx text ("Anaemia")
putdocx paragraph
collect clear
collect use models_anaemia
putdocx collect


*Table 2 - age when risk > thresholds
putdocx pagebreak
putdocx paragraph
putdocx text ("Age at which risk exceeded 2%, 3%, 6%")

putdocx paragraph
putdocx table tbl1 = data("symptom_desc women_age_2p women_age_3p women_age_6p men_age_2p men_age_3p men_age_6p"), varnames


*Save word file
local todaydate: display %tdCCYY-NN-DD =daily("`c(current_date)'","DMY")
putdocx save automodels_main_`todaydate'.docx, replace

