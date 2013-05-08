  class Vitals
	include CoreService
	require 'bean'
	require 'json'
	require 'rest_client'

			def self.get_patient_attribute_value(patient, attribute_name, session_date = Date.today)

				sex = patient.gender.upcase
				sex = 'M' if patient.gender.upcase == 'MALE'
				sex = 'F' if patient.gender.upcase == 'FEMALE'

				case attribute_name.upcase
				when "AGE"
					return patient.age
				when "RESIDENCE"
					return patient.address
				when "SYSTOLIC BLOOD PRESSURE"
					return self.current_vitals(patient, attribute_name).value_numeric
				when "DIASTOLIC BLOOD PRESSURE"
					return self.current_vitals(patient, attribute_name).value_numeric
				when "PATIENT HAS DIABETES"
					return self.current_vitals(patient, attribute_name).value_coded
				when "CURRENT_HEIGHT"
					obs = patient.person.observations.before((session_date + 1.days).to_date).question("HEIGHT (CM)").all
					return obs.first.answer_string.to_f rescue 0
				when "CURRENT_WEIGHT"
					obs = patient.person.observations.before((session_date + 1.days).to_date).question("WEIGHT (KG)").all
					return obs.first.answer_string.to_f rescue 0
				when "INITIAL_WEIGHT"
					obs = patient.person.observations.old(1).question("WEIGHT (KG)").all
					return obs.last.answer_string.to_f rescue 0
				when "INITIAL_HEIGHT"
					obs = patient.person.observations.old(1).question("HEIGHT (CM)").all
					return obs.last.answer_string.to_f rescue 0
				when "INITIAL_BMI"
					obs = patient.person.observations.old(1).question("BMI").all
					return obs.last.answer_string.to_f rescue nil
				when "MIN_WEIGHT"
					return WeightHeight.min_weight(sex, patient.age_in_months).to_f
				when "MAX_WEIGHT"
					return WeightHeight.max_weight(sex, patient.age_in_months).to_f
				when "MIN_HEIGHT"
					return WeightHeight.min_height(sex, patient.age_in_months).to_f
				when "MAX_HEIGHT"
					return WeightHeight.max_height(sex, patient.age_in_months).to_f
				end

			end

			def self.current_treatment_encounter(patient, date = Time.now(), provider = user_person_id)
				type = EncounterType.find_by_name("TREATMENT")
				encounter = patient.encounters.find(:first,:conditions =>["encounter_datetime BETWEEN ? AND ? AND encounter_type = ?",
													date.to_date.strftime('%Y-%m-%d 00:00:00'),
													date.to_date.strftime('%Y-%m-%d 23:59:59'),
													type.id])
				encounter ||= patient.encounters.create(:encounter_type => type.id,:encounter_datetime => date, :provider_id => provider)
			end

			def self.current_vitals(patient, vital_sign, session_date = Time.now())
				concept = ConceptName.find_by_name(vital_sign).concept_id
				Observation.find(:first,:order => "obs_datetime DESC, date_created DESC",
                                  :conditions =>["DATE(obs_datetime) <= ? AND person_id = ? AND concept_id = ?",
                                  session_date,patient.id, concept])
			end

			def self.current_encounter(patient, enc, concept, session_date = Date.today)
				concept = ConceptName.find_by_name(concept).concept_id
				encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  session_date ,patient.id,EncounterType.find_by_name(enc).id]).encounter_id
				Observation.find(:all, :order => "obs_datetime DESC,date_created DESC", :conditions => ["encounter_id = ? AND concept_id = ?", encounter, concept])
			end
end

