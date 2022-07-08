-- ---------------------------------------------------------------------------------------
-- 3. Analysis file - fatigue cohort only
-- ---------------------------------------------------------------------------------------
-- Creates one row per patient analysis file, containing cohort of patients with fatigue
-- Subsequent SQL files will later join symptoms and tests to this
-- --------------------------------------------------------------------------------


-- -----------------------------------------------------------------------
-- Format ranked eligible fatigue events file after import from Stata

-- Create index
CREATE INDEX `epatid` ON becky.fat2_fatigueevents_elig_ranked (`epatid`);

-- Reformat date column
set sql_safe_updates=0;
update becky.fat2_fatigueevents_elig_ranked set eventdate = str_to_date(eventdate, '%Y %M %e');
alter table becky.fat2_fatigueevents_elig_ranked modify eventdate date;
update becky.fat2_fatigueevents_elig_ranked set deathdate = NULL where deathdate = '.';
update becky.fat2_fatigueevents_elig_ranked set deathdate = str_to_date(deathdate, '%Y %M %e');
alter table becky.fat2_fatigueevents_elig_ranked modify deathdate date;

-- -----------------------------------------------------------------------
-- Create patient cohort with an eligible fatigue index date
drop table if exists  becky.fat2_cohort_elig;
create table becky.fat2_cohort_elig
select distinct(epatid), deathdate -- , valid_symp_start, valid_symp_end
from becky.fat2_fatigueevents_elig_ranked d
where forder_v_fc1yr = 1
;
CREATE INDEX `epatid` ON becky.fat2_cohort_elig (`epatid`);

-- Check: 285,382 rows 
select count(epatid)
from becky.fat2_cohort_elig
;

-- -----------------------------------------------------------------------
-- Join index fatigue event and cancer diagnoses to patient level fatigue pain cohort
drop table if exists  becky.fat2_dataset_characterisation;
create table becky.fat2_dataset_characterisation
(
select 
d.epatid, d.regstart, d.regend, d.deathdate,
d.d_epracid, d.d_uts, d.d_lcd, d.d_crd, d.d_crd_oneyear, d.d_tod, d.d_yob, d.d_dob 

, a.d_age30_date 
, a.d_age100_date
, p.gender
, i.imd2015_10
, l1.eventdate as fatigue_date
, l2.eventdate as cancer_date
, l2.cancer_site_number
, l2.cancer_site_desc

from cprd_case_file d

inner join becky.fat2_cohort_elig l on d.epatid = l.epatid
left join becky.fat2_cohort_prov a on d.epatid = a.epatid
left join cprd_patient p on d.epatid = p.epatid
left join imd_2015 i on d.epatid = i.epatid
left join becky.fat2_fatigueevents_elig_ranked l1  on d.epatid = l1.epatid and l1.forder_v_fc1yr = 1
left join becky.fat2_fatigueevents_elig_ranked l2  on d.epatid = l2.epatid and l2.cancer_order = 1

)
;
CREATE INDEX `epatid` ON becky.fat2_dataset_characterisation (`epatid`);
CREATE INDEX `fatigue_date` ON becky.fat2_dataset_characterisation (`fatigue_date`);
 

-- Check: 285,382 rows 
select count(epatid)
from becky.fat2_dataset_characterisation
;

-- --------------------------------------------------------------------------
-- Continue in SQL file 4.
-- -----------------------------------------------------------------------
