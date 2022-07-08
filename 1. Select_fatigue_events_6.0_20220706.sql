-- ---------------------------------------------------------------------------------------
-- 1. Select fatigue events
-- ---------------------------------------------------------------------------------------
-- Begin data management stage with this file
-- Select relevant fatigue events
-- These will then be sorted chronologically in Stata
-- --------------------------------------------------------------------------------


-- --------------------------------------------------------------------------------
	-- Section A) Create basic fatigue events file

-- Select all fatigue events
drop table if exists  becky.fat2_fatigueevents;
Create table becky.fat2_fatigueevents 
(KEY d_cprdclin_key (d_cprdclin_key))
ENGINE=MyISAM
select d.d_cprdclin_key, d.epatid, d.eventdate, d.medcode, l.readcode, l.readcode_desc, l.new_code
from cprd_clinical d
inner join becky.lookup_core_symptom_e2p2c_readcode l on d.medcode = l.medcode and l.symptom_number = 8
;

CREATE INDEX `medcode` ON becky.fat2_fatigueevents (`medcode`);
CREATE INDEX `epatid` ON becky.fat2_fatigueevents (`epatid`);
CREATE INDEX `eventdate` ON becky.fat2_fatigueevents (`eventdate`);


-- Check: 461,871 patients
select count(epatid), count(distinct epatid)
from becky.fat2_fatigueevents
;

-- Check: 314,152 patients with any record of fatigue in CPRD within overall study period (doesn't have to be eligible)
select count(distinct epatid)
from becky.fat2_fatigueevents d
where d.eventdate >= makedate(2007, 1)
AND d.eventdate <= makedate(2015, 92) -- include patients in 2014 as follow up for cancers in now < 12 months (probably 9 months)
;

-- --------------------------------------------------------------------------------
	-- Section B) Create eligible fatigue events file

-- Select any fatigue events, if:
	-- After UTS and CRD date 
	-- Before LCD, TOD, death date

-- Then flag eligible fatigue events if within study dates and age range, and registered to practice for one year
drop table if exists  becky.fat2_fatigueevents_elig;
create table becky.fat2_fatigueevents_elig
(select d.d_cprdclin_key, d.epatid, d.eventdate, d.medcode, d.readcode, d.readcode_desc

, case 
when d.eventdate >= l.d_crd_oneyear
AND  d.eventdate >= date_add(l.d_dob, interval 30 year)
AND d.eventdate <= date_add(l.d_dob, interval 100 year)
AND d.eventdate >= makedate(2007, 1)
AND d.eventdate <= makedate(2015, 92)
then 1
else 0
end as validfat

, l.d_uts, l.d_crd, l.d_lcd, l.d_tod, l.deathdate, l.d_crd_oneyear, l.d_dob

from becky.fat2_fatigueevents d
LEFT JOIN cprd_case_file l ON  d.epatid = l.epatid
WHERE d.eventdate >= l.d_uts
AND  d.eventdate >= l.d_crd

AND d.eventdate <= l.d_lcd
AND (d.eventdate <= l.d_tod or l.d_tod is null)
AND (d.eventdate <= l.deathdate or l.deathdate is null) 
)
;

CREATE INDEX `eventdate` ON becky.fat2_fatigueevents_elig (`eventdate`);
CREATE INDEX `epatid` ON becky.fat2_fatigueevents_elig (`epatid`);
CREATE INDEX `medcode` ON becky.fat2_fatigueevents_elig (`medcode`);

-- Check: 292,228 patients have an eligible fatigue event
select count(epatid), count(distinct epatid)
from becky.fat2_fatigueevents_elig
where validfat = 1
;

-- --------------------------------------------------------------------------------------------
	-- Section C) Create provisional fatigue cohort file for joins

-- Create 'provisional' patient cohort with eligible fatigue event from 2007- March 2015
drop table if exists  becky.fat2_cohort_prov;
create table becky.fat2_cohort_prov
select distinct(d.epatid)
, l.d_uts, l.d_crd, l.d_lcd, l.d_tod, l.deathdate, l.d_crd_oneyear, l.d_dob

, date_add(l.d_dob, interval 30 year) as d_age30_date
, date_add(l.d_dob, interval 100 year) as d_age100_date

from becky.fat2_fatigueevents_elig d
left join cprd_case_file l ON  d.epatid = l.epatid
where d.validfat = 1
;
CREATE INDEX `epatid` ON becky.fat2_cohort_prov (`epatid`);

-- Check: 292,228 patients
select count(epatid), count(distinct epatid)
from becky.fat2_cohort_prov
;


-- --------------------------------------------------------------------------------------------
	-- Section D) Join fatigue and cancer events to then order chronologically in Stata

-- Join cancers and fatigue events
drop table if exists  becky.fat2_fatiguecancers_events;
create table becky.fat2_fatiguecancers_events

Select *
from

(
select d.d_cprdclin_key as origin_id, 
case when d.epatid is not null then 1 else null end as eventtype
, d.epatid, d.eventdate, d.medcode as origin_code
, d.validfat
, case when d.epatid is not null then 0 else null end as cancer_site_number
, case when d.epatid is not null then 0 else null end as cancer_site_desc
, l.d_uts, l.d_crd, l.d_lcd, l.d_tod, l.deathdate, l.d_age30_date, l.d_age100_date, l.d_crd_oneyear, l.d_dob

from becky.fat2_fatigueevents_elig d
inner join becky.fat2_cohort_prov l on d.epatid = l.epatid

UNION ALL

Select d.e_cr_id as origin_id,  
case when d.epatid is not null then 2 else null end as eventtype
, d.epatid, d.diagnosisdate as eventdate, d.site_icd10_o2 as origin_code
, case when d.epatid is not null then 0 else null end as validfat
, l2.cancer_site_number, l2.cancer_site_desc as lookup_desc
, l.d_uts, l.d_crd, l.d_lcd, l.d_tod, l.deathdate, l.d_age30_date, l.d_age100_date, l.d_crd_oneyear, l.d_dob
from cancer_registration d
inner join becky.fat2_cohort_prov l on d.epatid = l.epatid
inner join becky.lookup_cancersite_v2 l2 on d.site_icd10_o2 = l2.icd10_4dig
) as tablename
;

CREATE INDEX `eventdate` ON becky.fat2_fatiguecancers_events (`eventdate`);
CREATE INDEX `epatid` ON becky.fat2_fatiguecancers_events (`epatid`);

-- Take off safe mode to enable column updates
set sql_safe_updates=0;

ALTER TABLE becky.fat2_fatiguecancers_events
modify eventtype  INT(1)  DEFAULT NULL
,modify validfat  INT(1)  DEFAULT NULL
;

-- Check: should be 649,670 events, 292,228 patients
select count(epatid), count(distinct epatid)
from becky.fat2_fatiguecancers_events;

-- Check: 25,334 patients with cancer
select count(epatid), count(distinct epatid)
from becky.fat2_fatiguecancers_events
where eventtype = 2;

-- --------------------------------------------------------------------------
-- Continue in Stata file 2.
-- -----------------------------------------------------------------------
