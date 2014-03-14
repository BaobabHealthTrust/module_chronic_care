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
