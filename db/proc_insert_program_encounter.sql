DROP TRIGGER IF EXISTS `program_encounter_and_details`;

DELIMITER $$


CREATE TRIGGER `program_encounter_and_details` AFTER INSERT ON `encounter`

FOR EACH ROW BEGIN
        SELECT encounter_type.encounter_type_id INTO @type FROM encounter_type WHERE name = 'VITALS' LIMIT 1;
        SELECT program_id INTO @program FROM program WHERE name = 'chronic care program' LIMIT 1;

        IF (NEW.encounter_type = @type) THEN
                  SELECT program_encounter_id INTO @program_encounter_id FROM program_encounter
                   WHERE NEW.patient_id = patient_id AND program_id = @program
                   AND DATE(date_time) = DATE(NEW.encounter_datetime) LIMIT 1;

                   IF  (@program_encounter_id IS NULL) THEN
                        INSERT INTO program_encounter (patient_id, date_time,program_id)
                        VALUES (NEW.patient_id, NEW.encounter_datetime, @program);

                        SELECT MAX(program_encounter_id) INTO @program_encounter_id FROM program_encounter LIMIT 1;
                    END IF;

                    INSERT INTO program_encounter_details (encounter_id, program_encounter_id, program_id, voided)
                    VALUES (NEW.encounter_id, @program_encounter_id, @program, 0);
        END IF;
END$$

DELIMITER ;

DROP VIEW IF EXISTS `start_date`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY INVOKER VIEW `start_date` AS select `p`.`patient_id` AS `patient_id`,`p`.`date_enrolled` AS `date_enrolled`,min(`o`.`obs_datetime`) AS `start_date`,`person`.`death_date` AS `death_date`
from ((`patient_program` `p` left join `patient_state` `s` on((`p`.`patient_program_id` = `s`.`patient_program_id`)))
inner join `obs` o on ((`o`.`person_id` = `p`.`patient_id`))
left join `person` on((`person`.`person_id` = `p`.`patient_id`)))
where ((`p`.`voided` = 0)

and (`s`.`voided` = 0)
and (`p`.`program_id` = 10)
and (`o`.`concept_id` = (select concept_id from concept_name  where name = 'cardiovascular system diagnosis' LIMIT 1))
and (`o`.`value_coded` != (select concept_id from concept_name  where name = 'normal'))) group by `p`.`patient_id`;

DROP VIEW IF EXISTS `dm_start_date`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY INVOKER VIEW `dm_start_date` AS select `p`.`patient_id` AS `patient_id`,`p`.`date_enrolled` AS `date_enrolled`,min(`o`.`obs_datetime`) AS `start_date`,`person`.`death_date` AS `death_date`
from ((`patient_program` `p` left join `patient_state` `s` on((`p`.`patient_program_id` = `s`.`patient_program_id`)))
inner join `obs` o on ((`o`.`person_id` = `p`.`patient_id`))
left join `person` on((`person`.`person_id` = `p`.`patient_id`)))
where ((`p`.`voided` = 0)

and (`s`.`voided` = 0)
and (`p`.`program_id` = 10)
and (`o`.`concept_id` = (select concept_id from concept_name  where name = 'Patient has diabetes' LIMIT 1))
and (`o`.`value_coded` = (select concept_id from concept_name  where name = 'yes'))) group by `p`.`patient_id`;
