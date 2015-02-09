DROP TRIGGER IF EXISTS `program_encounter_and_details`;

DROP VIEW IF EXISTS `start_date`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY INVOKER VIEW `start_date` AS select `p`.`patient_id` AS `patient_id`,`p`.`date_created` AS `date_enrolled`,min(`o`.`obs_datetime`) AS `start_date`,`person`.`death_date` AS `death_date`
from (`patient` p
inner join `obs` o on ((`o`.`person_id` = `p`.`patient_id`))
left join `person` on((`person`.`person_id` = `p`.`patient_id`)))
where ((`p`.`voided` = 0)
and (`o`.voided = 0)
and (`o`.`concept_id` = (select concept_id from concept_name  where name = 'cardiovascular system diagnosis' LIMIT 1))
and (`o`.`value_coded` != (select concept_id from concept_name  where name = 'normal'))) group by `p`.`patient_id`;

DROP VIEW IF EXISTS `dm_start_date`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY INVOKER VIEW `dm_start_date` AS select DISTINCT(`p`.`patient_id`) AS `patient_id`,`p`.`date_created` AS `date_enrolled`
from (`patient` p
inner join `encounter` e on ((`e`.`patient_id` = `p`.`patient_id`)))
where ((`p`.`voided` = 0)
and (`e`.`encounter_type` = (select encounter_type_id from encounter_type  where name = 'Diabetes Hypertension Initial Visit' LIMIT 1)));
