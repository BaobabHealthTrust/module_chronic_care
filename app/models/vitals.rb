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
	end
