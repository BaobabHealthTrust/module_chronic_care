class ReportController < ApplicationController

	def cohort
		 @quarter = params[:quarter]
		 @logo = CoreService.get_global_property_value('logo').to_s
	end

	def cohort_menu
		render :layout => "application"
	end
	
	def ccc_register
		@logo = CoreService.get_global_property_value('logo').to_s
		@report_name = "Chronic Care Clinic Register"
		@total = []
		@gender = {}
		@location = {}
		@gender["F"] = 0
		@gender["M"] = 0
		(Clinic.total_in_program(Program.find_by_concept_id(Concept.find_by_name('CHRONIC CARE PROGRAM').id).id) || []).each do |patient|
			pat = Patient.find(patient.patient_id)
			sex = pat.gender
			sex = "F" if pat.gender == "Female"
			sex = "M" if pat.gender == "Male"
			@gender[sex] += 1
			(@location[pat.address].nil?) ? @location[pat.address] = 1 : @location[pat.address] += 1
			@total << [pat.name, sex, pat.age, pat.address]
		end
		
	end

	def hypertension_report
		@logo = CoreService.get_global_property_value('logo').to_s
		@report_name = "Hypertension Report"
		@stages = {}
		@gender_break = {}
		@age_break = {}
		@location_break = {}

		concept_id =  ConceptName.find_by_name("cardiovascular system diagnosis").concept_id
	  (Clinic.total_in_program(Program.find_by_concept_id(Concept.find_by_name('CHRONIC CARE PROGRAM').id).id) || []).each do |patient|
			obs = Observation.find(:first, :conditions => ["person_id = ? AND concept_id = ?", patient.patient_id, concept_id]) rescue nil
			if ! obs.blank?
				pat = Patient.find(patient.patient_id)
				sex = pat.gender
				sex = "F" if pat.gender == "Female"
				sex = "M" if pat.gender == "Male"

				age = pat.age.to_i 

				age = 30 if age < 40
				
				age = 40 if age >= 40 and age < 50
					
				age = 50 if age >= 50 and age < 60

				age = 60 if age >= 60 and age < 70

				age = 70 if age >= 70 and age < 80
				
				age = 80 if age >= 80

				stage = obs.value_text if ! obs.value_text.blank?
				stage = ConceptName.find_by_concept_id(obs.value_coded).name if ! obs.value_coded.blank?
				@stages[stage] += 1 rescue @stages[stage] = 1
				@gender_break[stage] = {} if @gender_break[stage].blank?
				@age_break[stage] = {} if @age_break[stage].blank?

				@location_break[stage] = {} if @location_break[stage].blank?

				if ! pat.address.blank?
					@location_break[stage][pat.address] += 1 rescue @location_break[stage][pat.address] = 1
				else
					@location_break[stage]["Unknown Address"] += 1 rescue @location_break[stage]["Unknown Address"] = 1
				end
				@gender_break[stage][sex] += 1 rescue @gender_break[stage][sex] = 1
				@age_break[stage][age] += 1 rescue @age_break[stage][age] = 1
			end
		end
		render :template => "/report/hypertension"

	end

	def diabetes_report
			
	end

	def assessment

	end

	def fsb_report

	end

	def epilepsy

	end
end
