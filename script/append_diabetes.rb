  program_id = Program.find_by_name('CHRONIC CARE PROGRAM').id
  diabetes_program_id = Program.find_by_name('DIABETES PROGRAM').id
  type = EncounterType.find_by_name("diabetes hypertension initial visit").encounter_type_id
  concept = ConceptName.find_by_name("Patient has diabetes").concept_id
  value_coded = ConceptName.find_by_name("YES").concept_id

  observations = Observation.find_by_sql("
                                         SELECT DISTINCT(r.patient_id) AS person_id FROM patient r
                                        WHERE r.patient_id NOT IN
                                        (Select distinct(o.person_id)
                                        from obs o
                                        where o.concept_id = (select concept_id from concept_name where name = 'patient has diabetes')
                                        and o.voided = 0)
                                        AND r.voided = 0")

  (observations || []).each {|person|
    patient = Patient.find(person.person_id) rescue []

    puts "Processing #{patient.name rescue ''} On :::::::#{person.person_id}"
    first_obs = Observation.find_by_sql("
                                  SELECT MIN(obs_datetime) AS start_date FROM obs
                                  WHERE person_id = #{person.person_id}
                                  AND voided = 0").first.start_date
      current = PatientProgram.find_by_program_id(program_id,
              :conditions => ["patient_id = ? AND COALESCE(date_completed, '') = ''", person.person_id])
     first_obs = patient.date_created if first_obs.blank?

    ActiveRecord::Base.transaction do
   
    if current.blank?
      puts "Enrolling #{person.person_id} into CCC"
      PatientProgram.create(
                :patient_id => person.person_id,
                :program_id => program_id,
                :date_enrolled => "#{first_obs}"
              )
    end


      puts "Creating Encounter for #{person.person_id}"
      encounter = Encounter.create(
            :patient_id => person.person_id,
            :provider_id => 1,
            :encounter_type => type,
            :location_id => 725,
            :encounter_datetime => "#{first_obs}"
          )

     program_encounter = ProgramEncounter.find_by_program_id(program_id,
              :conditions => ["patient_id = ? AND DATE(date_time) = ?",
                person.person_id, first_obs.to_date.strftime("%Y-%m-%d")])

      if program_encounter.blank?

              program_encounter = ProgramEncounter.create(
                :patient_id => person.person_id,
                :date_time => first_obs,
                :program_id => program_id
              )

      end


     puts "#{program_encounter.program_encounter_id}"
     ProgramEncounterDetail.create(
                  :encounter_id => encounter.id.to_i,
                  :program_encounter_id => program_encounter.id,
                  :program_id => program_id
                )

    puts "Set Diabetes Observation for #{person.person_id}"
    obs = Observation.create(
                :person_id => person.person_id,
                :concept_id => concept,
                :location_id => encounter.location_id,
                :obs_datetime => encounter.encounter_datetime,
                :encounter_id => encounter.encounter_id,
                :value_coded => value_coded
              )
    end
  }