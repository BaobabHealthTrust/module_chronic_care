class CheckEncounterController < ApplicationController
  def self.done_already(patient_id, program_id, date,type, encounter)

    if type.downcase == "module"
            modular_approach = Encounter.find_by_sql("
                                SELECT * FROM encounter e
                                INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
                                INNER JOIN program_encounter_details p
                                ON p.encounter_id = e.encounter_id
                                WHERE p.voided = 0
                                AND e.person_id = '#{patient_id}'
                                AND DATE(e.encounter_datetime) = '#{date}'
                                AND p.program_id != '#{program_id}'
                                AND et.name = '#{encounter}'")
    else
           modular_approach = Encounter.find_by_sql("
                                SELECT * FROM encounter e
                                INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
                                INNER JOIN obs o
                                ON p.encounter_id = e.encounter_id
                                WHERE o.voided = 0
                                AND e.person_id = '#{patient_id}'
                                AND DATE(e.encounter_datetime) = '#{date}'
                                AND et.name = '#{encounter}'")
    end
    return modular_approach
  end
end
