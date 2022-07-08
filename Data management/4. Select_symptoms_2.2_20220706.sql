-- ---------------------------------------------------------------------------------------
-- 4. Select additional symptoms
-- ---------------------------------------------------------------------------------------
-- Select other potential cancer symptom events, for the fatigue cohort
-- These will later be sorted chronologically in Stata
-- --------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------
-- Section A: Check Read codes


-- Check for  0  medcodes
select *
from becky.lookup_core_symptom_e2p2c_readcode
where medcode = 0
order by medcode;


-- Check for duplicate read codes within a symptom
select *
from becky.lookup_core_symptom_e2p2c_readcode as d
inner join (
select symptom_number, readcode, count(readcode)
from becky.lookup_core_symptom_e2p2c_readcode as d
group by symptom_number, readcode
having count(readcode) > 1
)temp on d.readcode = temp.readcode;


-- Check for any duplicate read codes across symptoms
select *
from becky.lookup_core_symptom_e2p2c_readcode as d
inner join (
select readcode, count(readcode)
from becky.lookup_core_symptom_e2p2c_readcode as d
group by readcode
having count(readcode) > 1
)temp on d.readcode = temp.readcode;


-- Check for duplicate med codes within a symptom
select *
from becky.lookup_core_symptom_e2p2c_readcode as d
inner join (
select symptom_number, medcode, count(medcode)
from becky.lookup_core_symptom_e2p2c_readcode as d
group by symptom_number, medcode
having count(medcode) > 1
)temp on d.medcode = temp.medcode;


-- Check for any duplicate med codes across symptoms
select *
from becky.lookup_core_symptom_e2p2c_readcode as d
inner join (
select medcode, count(medcode)
from becky.lookup_core_symptom_e2p2c_readcode as d
group by medcode
having count(medcode) > 1
)temp on d.medcode = temp.medcode;


-- ---------------------------------------------------------------------------------------
-- Section B) Create list of all relevant (alarm and vague) symptoms occuring 12 mo before/ 3m after fatigue presentation

-- List all events occurring 12 mo before/ 3m after fatigue presentation
drop table if exists  becky.fat2_allevents_clin;
create table becky.fat2_allevents_clin
(
select d.epatid, d.medcode, d.eventdate, l.fatigue_date, l.cancer_date
from cprd_clinical as d
inner join becky.fat2_dataset_characterisation l on d.epatid = l.epatid 
and d.eventdate <= date_add(l.fatigue_date, interval 3 month) 
and d.eventdate >= date_sub(l.fatigue_date, interval 12 month)
)
;

-- Add indexes
create index medcode on becky.fat2_allevents_clin (medcode);
create index epatid on becky.fat2_allevents_clin (epatid);
create index eventdate on becky.fat2_allevents_clin (eventdate);
create index fatigue_date on becky.fat2_allevents_clin (fatigue_date);

-- Check: 11,028,817 events, 285,382 patients
select count(epatid), count(distinct epatid)
from becky.fat2_allevents_clin as d
;


-- Flag whether symptoms are "eligible"
drop table if exists  becky.fat2_allsymptoms_clin;
create table becky.fat2_allsymptoms_clin
(
select d.*,
l2.symptom_number,
l2.symptom_desc, 
l2.readcode,
l2.readcode_desc,
l2.alarm_vague,

-- Flag as eligible symptom, if:
	-- After UTS and CRD date
	-- Before LCD, TOD, death date, cancer diagnosis date
case when d.eventdate >= l.d_uts
AND  d.eventdate >= l.d_crd
AND d.eventdate <= l.d_lcd
AND (d.eventdate <= l.d_tod or l.d_tod is null)
AND (d.eventdate <= l.deathdate or l.deathdate is null) 
AND (d.eventdate <= d.cancer_date or d.cancer_date is null)
then 1 else 0 end as elig_event

from becky.fat2_allevents_clin as d
LEFT JOIN cprd_case_file l ON  d.epatid = l.epatid
left join becky.lookup_core_symptom_e2p2c_readcode as l2 on d.medcode = l2.medcode
)
;

-- Add indexes
create index medcode on becky.fat2_allsymptoms_clin (medcode);
create index epatid on becky.fat2_allsymptoms_clin (epatid);
create index eventdate on becky.fat2_allsymptoms_clin (eventdate);
create index fatigue_date on becky.fat2_allsymptoms_clin (fatigue_date);
create index symptom_number on becky.fat2_allsymptoms_clin (symptom_number);
create index readcode on becky.fat2_allsymptoms_clin (readcode);


-- ---------------------------------------------------------------------------------------
-- Checks

-- Check: Any event - 11,028,817 events, 285,382 patients
select count(epatid), count(distinct epatid)
from becky.fat2_allsymptoms_clin as d
;

-- Check: Any symptom - 1,021,555 events
select count(epatid), count(distinct epatid)
from becky.fat2_allsymptoms_clin as d
where symptom_number is not null
;

-- Check: 1,796 patients with weight loss occurring 3 months before / 1 months after fatigue, and eligible
select alarm_vague, symptom_number, symptom_desc, count(epatid), count(distinct epatid)
from becky.fat2_allsymptoms_clin as d
where eventdate < date_add(fatigue_date, interval 1 month) and eventdate >= date_sub(fatigue_date, interval 3 month)
and elig_event = 1 -- eligible
group by alarm_vague, symptom_number, symptom_desc
order by alarm_vague, count(epatid) desc
;

-- Check: haematuria (regardless of timing or eligibility) - 3137 patients, 4278 rows
select count(epatid), count(distinct epatid)
from becky.fat2_allsymptoms_clin as d
where symptom_number = 9
;

-- Check: pelvic pain (regardless of timing or eligibility) - 371 patients, 418 records
select count(epatid), count(distinct epatid)
from becky.fat2_allsymptoms_clin as d
where symptom_number = 20
;

-- --------------------------------------------------------------------------
-- Continue in SQL file 5.
-- -----------------------------------------------------------------------
