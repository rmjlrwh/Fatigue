-- ---------------------------------------------------------------------------------------
-- 3. Analysis file - fatigue cohort only
-- ---------------------------------------------------------------------------------------
-- Format chronologically sorted symptom and test files
-- Join sorted symptom/ tests event files onto the previously created 'one row per patient' analysis file
-- --------------------------------------------------------------------------------


-- -------------------------------------------------s--------------------------------------
-- Section A) Format chronologically sorted symptoms file

-- Create index
CREATE INDEX `epatid` ON becky.fat2_othersymptoms_elig_ranked (`epatid`);

-- Reformat date column
set sql_safe_updates=0;
update becky.fat2_othersymptoms_elig_ranked set eventdate = str_to_date(eventdate, '%Y %M %e');

-- Check: 285382 patients,  11,029,309 records
select count(epatid), count(distinct epatid)
from becky.fat2_othersymptoms_elig_ranked
;

-- Check: No. weight loss - 3733 patients, 4500 records
select count(epatid), count(distinct epatid)
from becky.fat2_othersymptoms_elig_ranked
where symptom_number = 15 and elig_event = 1 
;

-- Check: No. weight loss 12 months before - 2801 patients, 3319 records
select count(epatid), count(distinct epatid)
from becky.fat2_othersymptoms_elig_ranked
where symp_15_latest_12mbf is not null
;

-- Check: No. weight loss 3 months before - 1 month after: 1790 patients, 1991 records
select count(epatid), count(distinct epatid)
from becky.fat2_othersymptoms_elig_ranked
where symptom_number = 15 and elig_event = 1
and daysdiff_fatindex > -91 and daysdiff_fatindex < 30.4
;

-- Check: No. haematuria 3 months before - 1 month after - 1,145 patients, 1,433 records
select count(epatid), count(distinct epatid)
from becky.fat2_othersymptoms_elig_ranked
where symptom_number = 9 and elig_event = 1
and daysdiff_fatindex > -91 and daysdiff_fatindex < 30.4
;

-- Check: No. pelvic pain 3 months before - 1 month after - 105 patients, 114 records
select count(epatid), count(distinct epatid)
from becky.fat2_othersymptoms_elig_ranked
where symptom_number = 20 and elig_event = 1
and daysdiff_fatindex > -91 and daysdiff_fatindex < 30.4
;


-- ---------------------------------------------------------------------------------------
-- Section B) Format chronologically sorted tests file

-- Add index
CREATE INDEX `epatid` ON becky.fat2_tests_elig_ranked (`epatid`);

-- Format dates
set sql_safe_updates=0;
update becky.fat2_tests_elig_ranked set eventdate = str_to_date(eventdate, '%Y %M %e');

-- Check:  247300 patients, 476544 records
select count(epatid), count(distinct epatid)
from becky.fat2_tests_elig_ranked
;

-- Check: No. elig hb values - 245977 patients, 469310 records
select count(epatid), count(distinct epatid)
from becky.fat2_tests_elig_ranked
where test_number = 108 and elig_event = 1 and value is not null
;

-- Check: No. low hb values 12 months before - 35,332 patients, 73,137 records
select count(epatid), count(distinct epatid)
from becky.fat2_tests_elig_ranked
where test_ab_108_latest_12mbf is not null
;

-- Check: Number of patients with low haemoglobin 3 months before - 1 month after- 37,011; records 53858
select count(epatid), count(distinct epatid)
from becky.fat2_tests_elig_ranked
where test_number = 108 and elig_event = 1 and abnormal = 1
and daysdiff_fatindex > -91 and daysdiff_fatindex < 30.4
;


-- -------------------------------------------------------------------------------------------
-- Section C) Copy patient level dataset before joining symptoms/ tests

drop table if exists becky.fat2_dataset_characterisation_2;
create table becky.fat2_dataset_characterisation_2 like becky.fat2_dataset_characterisation;
insert into becky.fat2_dataset_characterisation_2 select * from becky.fat2_dataset_characterisation;


-- -------------------------------------------------------------------------------------------
-- Section D) Join symptom dates to patient level dataset

-- Take off safe mode to enable column updates
set sql_safe_updates=0;

-- Loop through each symptom
DROP PROCEDURE IF EXISTS p;
delimiter $$
CREATE PROCEDURE p()

BEGIN
DECLARE x  INT;
SET x = 0;

WHILE x  <=45 DO

-- First command
   set @sql= (
select concat(
'Alter table becky.fat2_dataset_characterisation_2
ADD symp_date_latest_12mbf_',x,' DATE DEFAULT NULL, 
ADD symp_date_earliest_3ma_',x,' DATE DEFAULT NULL 
;'
)
);
    select @sql;
   prepare sqlstmt from @sql;
   execute sqlstmt;
   deallocate prepare sqlstmt;

-- Second command
   set @sql= (
select concat(
'Update becky.fat2_dataset_characterisation_2 as d
left join becky.fat2_othersymptoms_elig_ranked l on d.epatid = l.epatid and l.symp_',x,'_latest_12mbf = 1
Set d.symp_date_latest_12mbf_',x,' = l.eventdate;'
)
);
    select @sql;
   prepare sqlstmt from @sql;
   execute sqlstmt;
   deallocate prepare sqlstmt;

-- Third command
   set @sql= (
select concat(
'Update becky.fat2_dataset_characterisation_2 as d
left join becky.fat2_othersymptoms_elig_ranked l on d.epatid = l.epatid and l.symp_',x,'_earliest_3ma = 1
Set d.symp_date_earliest_3ma_',x,' = l.eventdate;'
)
);
    select @sql;
   prepare sqlstmt from @sql;
   execute sqlstmt;
   deallocate prepare sqlstmt;

     SET x=x+1;

END WHILE;
END$$

DELIMITER ;
CALL p();


-- Drop non-existent symptom numbers
Alter table becky.fat2_dataset_characterisation_2
DROP symp_date_latest_12mbf_41, 
DROP symp_date_earliest_3ma_41,
DROP symp_date_latest_12mbf_42, 
DROP symp_date_earliest_3ma_42,
DROP symp_date_latest_12mbf_46, 
DROP symp_date_earliest_3ma_46;


-- Check: Number patients with weigh tloss 12 months before - 2801 patients
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where symp_date_latest_12mbf_15 is not null
;

-- Check: Number patients with weight loss 3 months after - 1038
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where symp_date_earliest_3ma_15 is not null
;

-- Check: Number patients with weight loss 3 months before - 1 month after - 1806
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where symp_date_earliest_3ma_15 <= date_add(fatigue_date, interval 1 month) 
or symp_date_latest_12mbf_15 >= date_sub(fatigue_date, interval 3 month)
;

-- Check: Number patients with haematuria 3 months before - 1 month after - 1,154
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where symp_date_earliest_3ma_9 <= date_add(fatigue_date, interval 1 month) 
or symp_date_latest_12mbf_9 >= date_sub(fatigue_date, interval 3 month)
;

-- Check: Number patients with pelvic pain 3 months before - 1 month after - 104
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where symp_date_earliest_3ma_20 <= date_add(fatigue_date, interval 1 month) 
or symp_date_latest_12mbf_20 >= date_sub(fatigue_date, interval 3 month)
;

-- Check: Number patients with pelvic pain 12 months before - 299 patients
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where symp_date_latest_12mbf_20 is not null
;

-- Check: Number patients with pelvic pain 12 months after - 76 patients
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where symp_date_earliest_3ma_20 is not null
;

-- Check: Number patients with thromboembolic 12 months before - 4788 patients
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where symp_date_latest_12mbf_45 is not null
;

-- Check: Number patients with thromboembolic 12 months after - 1994 patients
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where symp_date_earliest_3ma_45 is not null
;


-- ---------------------------------------------------------------------------------------
-- Section E) Add tests to fatigue dataset

-- Take off safe mode to enable column updates
set sql_safe_updates=0;

-- Add test  variable names
Alter table becky.fat2_dataset_characterisation_2
ADD test_date_latest_12mbf_108 DATE DEFAULT NULL, 
ADD test_date_earliest_3ma_108 DATE DEFAULT NULL, 
ADD test_ab_date_latest_12mbf_108 DATE DEFAULT NULL, 
ADD test_ab_date_earliest_3ma_108 DATE DEFAULT NULL 
;

-- Add test cohort flag - 12 months before
Update becky.fat2_dataset_characterisation_2 as d
left join becky.fat2_tests_elig_ranked l on d.epatid = l.epatid and l.test_108_latest_12mbf = 1
Set d.test_date_latest_12mbf_108 = l.eventdate;

-- Add test cohort flag - 3 months after
Update becky.fat2_dataset_characterisation_2 as d
left join becky.fat2_tests_elig_ranked l on d.epatid = l.epatid and l.test_108_earliest_3ma = 1
Set d.test_date_earliest_3ma_108 = l.eventdate;


-- Add abnormal test cohort flag - 12 months before
Update becky.fat2_dataset_characterisation_2 as d
left join becky.fat2_tests_elig_ranked l on d.epatid = l.epatid and l.test_ab_108_latest_12mbf = 1
Set d.test_ab_date_latest_12mbf_108 = l.eventdate;

-- Add abnormal test cohort flag - 3 months after
Update becky.fat2_dataset_characterisation_2 as d
left join becky.fat2_tests_elig_ranked l on d.epatid = l.epatid and l.test_ab_108_earliest_3ma = 1
Set d.test_ab_date_earliest_3ma_108 = l.eventdate;


-- Check: Number patients with low hb  12 months before - 35,332
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where test_ab_date_latest_12mbf_108 is not null
;

-- Check: Number patients with low hb 3 months after - 29,889
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where test_ab_date_earliest_3ma_108 is not null
;

-- Check: Number patients with low hb 3 months before - 1 month after - 37,133  
select count(epatid), count(distinct epatid)
from becky.fat2_dataset_characterisation_2
where test_ab_date_earliest_3ma_108 <= date_add(fatigue_date, interval 1 month) 
or test_ab_date_latest_12mbf_108 >= date_sub(fatigue_date, interval 3 month)
;

-- --------------------------------------------------------------------------
-- Data management stage is  complete
-- Continue to analysis stage in Stata
-- -----------------------------------------------------------------------

