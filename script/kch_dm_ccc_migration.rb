
  program_id = Program.find_by_name('CHRONIC CARE PROGRAM').id
  diabetes_program_id = Program.find_by_name('DIABETES PROGRAM').id

  puts "#{program_id}"
  encounters = Encounter.find_by_sql("
    SELECT distinct(DATE(encounter_datetime)) AS dates FROM encounter
    WHERE voided = 0
    AND encounter_id NOT IN
    (SELECT distinct(encounter_id) FROM program_encounter_details)")
  total = encounters.length
  
   encounters.each{|datetimes|
      total -= 1
      puts "Encounters #{total} to go........"
       Encounter.find_by_sql("
      SELECT encounter_id, patient_id FROM encounter
      WHERE voided = 0
      AND DATE(encounter_datetime) = '#{datetimes.dates}'
      AND encounter_id NOT IN
     (SELECT distinct(encounter_id) FROM program_encounter_details)
      ").each{|visit|
      patient_id = visit.patient_id
      patient_encounter_detail = ProgramEncounter.find_by_sql(
                "SELECT * FROM program_encounter WHERE
                patient_id = #{patient_id}
                AND program_id = #{program_id}
                AND DATE(date_time) = '#{datetimes.dates}'
                ")
              if patient_encounter_detail.blank? == true
                ActiveRecord::Base.transaction do
                pp = ProgramEncounter.new
                pp.program_id = program_id
                pp.patient_id = patient_id
                pp.date_time = datetimes.dates
                pp.save
                #puts "Saving #{pp.program_encounter_id}"
                Encounter.find_by_sql("
                          SELECT encounter_id FROM encounter
                          WHERE voided = 0
                          AND DATE(encounter_datetime) = '#{datetimes.dates}'
                          AND patient_id = #{patient_id}").each{|entered_encounters|
                            ppd = ProgramEncounterDetail.new
                            ppd.encounter_id = entered_encounters.encounter_id
                            ppd.program_encounter_id = pp.program_encounter_id
                            ppd.voided = 0
                            ppd.program_id = program_id
                            ppd.save
                            #puts "Saving #{ppd.id}"
                          }
                end
              else
                ActiveRecord::Base.transaction do
                 Encounter.find_by_sql(
                            "SELECT * FROM encounter WHERE
                            patient_id = #{patient_id}
                            AND DATE(encounter_datetime) = '#{datetimes.dates}'
                            AND encounter_id NOT IN (SELECT distinct(encounter_id) FROM program_encounter p
                                                    INNER JOIN program_encounter_details pd ON p.program_encounter_id = pd.program_encounter_id
                                                    WHERE DATE(date_time) = '#{datetimes.dates}')
                            ").each{|entered_encounters|
                            ppd = ProgramEncounterDetail.new
                            ppd.encounter_id = entered_encounters.encounter_id
                            ppd.program_encounter_id = patient_encounter_detail.first.program_encounter_id
                            ppd.voided = 0
                            ppd.program_id = program_id
                            ppd.save
                            #puts "Saving #{ppd.id}"
                          }
                end
              end



      }
     
    }

    #Updating states
 #ActiveRecord::Base.transaction do
 #puts "here"
PatientProgram.find_by_sql("
          SELECT * FROM patient_program WHERE program_id = #{diabetes_program_id}
          AND voided = 0").each{|program|
          program.program_id = program_id
          program.save
          puts "Updating program for patient #{program.patient_id}"
          }
# Correcting encounters
new_encounter_id = EncounterType.find_by_name('DIABETES HYPERTENSION INITIAL VISIT').id
Encounter.find_by_sql("
    SELECT * FROM encounter
    WHERE voided = 0
    AND encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'DIABETES INITIAL QUESTIONS')").each{|encounter_type|
     encounter_type.encounter_type = new_encounter_id
     encounter_type.save
     puts "Updating encounter type #{encounter_type.encounter_id}"
    }

  

