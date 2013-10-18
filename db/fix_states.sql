-- --------------------------------------------------------------------------------
-- Routine DDL
-- Note: comments before and after the routine body will not be stored by the server
-- --------------------------------------------------------------------------------
DELIMITER $$

CREATE DEFINER=`root`@`localhost` FUNCTION `current_state_for_program`(my_patient_id INT, my_program_id INT, my_end_date DATETIME) RETURNS int(11)
BEGIN
  SET @state_id = NULL;
	SELECT  patient_program_id INTO @patient_program_id FROM patient_program 
			WHERE patient_id = my_patient_id 
				AND program_id = my_program_id 
				AND voided = 0 
				ORDER BY patient_program_id DESC LIMIT 1;

	SELECT state INTO @state_id FROM patient_state 
		WHERE patient_program_id = @patient_program_id
			AND voided = 0
			AND start_date <= my_end_date
		ORDER BY start_date DESC, date_created DESC, patient_state_id DESC LIMIT 1;

	RETURN @state_id;
END
