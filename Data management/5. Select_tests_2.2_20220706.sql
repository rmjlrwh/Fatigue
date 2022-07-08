-- ---------------------------------------------------------------------------------------
-- 5. Select additional tests (incl. anaemia)
-- ---------------------------------------------------------------------------------------
-- Select test events, for the fatigue cohort
-- Multiple tests (not just haemoglobin) are selected here. This is later restricted just to haemoglobin tests.
-- Test events will later be sorted chronologically in Stata
-- --------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------
-- Section A) Create list of tests occuring 12 mo before/ 3m after fatigue presentation

-- All events occurring 12 mo before/ 3m after fatigue presentation
drop table if exists  becky.fat2_alltests;
create table becky.fat2_alltests
(
select d.epatid, d.eventdate, d.enttype, d.medcode, d.data1, d.data2, d.data3, d.data4, d.data5, d.data6, d.data7, d.data8, l.fatigue_date, l.cancer_date
from cprd_test d
inner join becky.fat2_dataset_characterisation l on d.epatid = l.epatid 
and d.eventdate <= date_add(l.fatigue_date, interval 3 month) 
and d.eventdate >= date_sub(l.fatigue_date, interval 12 month)
)
;

-- Add indexes
create index enttype on becky.fat2_alltests (enttype);
create index epatid on becky.fat2_alltests (epatid);
create index eventdate on becky.fat2_alltests (eventdate);
create index fatigue_date on becky.fat2_alltests (fatigue_date);

-- Check: 16,504,439 events, 275,474 patients
select count(epatid), count(distinct epatid)
from becky.fat2_alltests as d
;

-- ---------------------------------------------------------------------------------------
-- Section B) Flag which events are of interest

-- Flag whether tests are of interest and "eligible"
drop table if exists  becky.fat2_alltests_elig;
create table becky.fat2_alltests_elig
(
select d.*,
l2.test_number,
l2.test_desc, 
l2.enttype_desc,

-- Flag as eligible symptom, if:
	-- After UTS and CRD date
	-- Before LCD, TOD, death date, cancer diagnosis date
case when d.eventdate >= l.d_uts
AND  d.eventdate >= l.d_crd
AND d.eventdate <= l.d_lcd
AND (d.eventdate <= l.d_tod or l.d_tod is null)
AND (d.eventdate <= l.deathdate or l.deathdate is null) 
AND (d.eventdate <= d.cancer_date or d.cancer_date is null)
then 1 else 0 end as elig_event,

l3.data1 as data1_lkup_desc,
l3.data1_lkup,
l3.data2 as data2_lkup_desc,
l3.data2_lkup,
l3.data3 as data3_lkup_desc,
l3.data3_lkup,
l3.data4 as data4_lkup_desc,
l3.data4_lkup,
l3.data5 as data5_lkup_desc,
l3.data5_lkup,
l3.data6 as data6_lkup_desc,
l3.data6_lkup,
l3.data7 as data7_lkup_desc,
l3.data7_lkup,
l3.data8 as data8_lkup_desc,
l3.data8_lkup,

l4.gender

from becky.fat2_alltests as d
LEFT JOIN cprd_case_file l ON  d.epatid = l.epatid
left join becky.lookup_core_symptom_e2p2_enttype as l2 on d.enttype = l2.enttype
left join lookup_entity as l3 on d.enttype = l3.enttype
left join cprd_patient l4 on d.epatid = l4.epatid
)
;

-- Add indexes
create index enttype on becky.fat2_alltests_elig (enttype);
create index epatid on becky.fat2_alltests_elig (epatid);
create index eventdate on becky.fat2_alltests_elig (eventdate);
create index fatigue_date on becky.fat2_alltests_elig (fatigue_date);
create index symptom_number on becky.fat2_alltests_elig (test_number);
create index medcode on becky.fat2_alltests_elig (medcode);
create index data1 on becky.fat2_alltests_elig (data1);
create index data3 on becky.fat2_alltests_elig (data3);
create index data4 on becky.fat2_alltests_elig (data4);

-- Check: 16,460,445 elig events, 275,408 patients
select count(epatid), count(distinct epatid)
from becky.fat2_alltests_elig as d
where elig_event = 1
;

-- ---------------------------------------------------------------------------------------
-- Section C) Add more test events from Test file using Read codes

-- Use entity type '288' other test, and then add medcodes for tests of interest captured by Read codes.
-- Take off safe mode to enable column updates
set sql_safe_updates=0;

update  becky.fat2_alltests_elig as d
left join becky.lookup_core_symptom_e2p2c_readcode as l on d.medcode = l.medcode
Set d.test_number = l.symptom_number 
where d.enttype = 288;

update  becky.fat2_alltests_elig as d
left join becky.lookup_core_symptom_e2p2c_readcode as l on d.medcode = l.medcode
Set d.test_desc = l.symptom_desc
where d.enttype = 288;

-- Check join symptom num join worked for haemoglobin. Yes - there are  no medcodes for haemoglobin under enttype other
select *
from becky.fat2_alltests_elig
where enttype = 288
and medcode in (4, 10404, 35749, 3942, 26910, 26909, 26272, 26913, 41531, 26908, 26912, 2405)
;

-- ---------------------------------------------------------------------------------------
-- Section D) Find lookup info for test results

/*
select * 
from lookup_entity as d
left join becky.lookup_core_symptom_e2p2_enttype as l on d.enttype = l.enttype
where l.enttype is not null
;

-- For all except 220 FBC:
data1 = Operator - use OPR lookup
data2 = Value
data3 = Unit of measurement - use SUM lookup
data4 = Qualifier - use TQR lookup
data5 = Normal range from
data6 = Normal range to
data7 = Normal range basis

-- For 220 FBC
data1 = Qualifier - TQU lookup
data2 = Normal range from
data3 = Normal range to
data4 = Normal range basis
*/

-- ---------------------------------------------------------------------------------------
-- Section E) Add detail about test results using lookup info

set sql_safe_updates=0;

alter table  becky.fat2_alltests_elig
add operator varchar(64) default null,
add unitmeasure varchar(64) default null,
add testqualifier varchar(64) default null
;

-- For all tests of interest except FBC
update  becky.fat2_alltests_elig as d
left join lookup_txtfiles_opr as l on d.data1 = l.code
Set d.operator = l.operator 
where d.enttype not in (288,220) -- not 'other' or 'FBC'
and d.test_number is not null
;

update  becky.fat2_alltests_elig as d
left join lookup_txtfiles_sum as l on d.data3 = l.code
Set d.unitmeasure = l.unitmeasure 
where d.enttype not in (288,220) -- not 'other' or 'FBC'
and d.test_number is not null
;

update  becky.fat2_alltests_elig as d
left join lookup_txtfiles_tqu as l on d.data4 = l.code
Set d.testqualifier = l.testqualifier 
where d.enttype not in (288,220) -- not 'other' or 'FBC'
and d.test_number is not null
;

-- For FBC
update  becky.fat2_alltests_elig as d
left join lookup_txtfiles_tqu as l on d.data1 = l.code
Set d.testqualifier = l.testqualifier 
where d.enttype = 220 --  'FBC'
and d.test_number is not null
;

-- ---------------------------------------------------------------------------------------
-- Section F) Add read code descriptions

set sql_safe_updates=0;

alter table  becky.fat2_alltests_elig
add readcode_desc varchar(64) default null
;

update  becky.fat2_alltests_elig as d
left join lookup_medical as l on d.medcode = l.medcode
Set d.readcode_desc = l.descc 
;

-- --------------------------------------------------------------------------
-- Continue in Stata file 6.
-- -----------------------------------------------------------------------
