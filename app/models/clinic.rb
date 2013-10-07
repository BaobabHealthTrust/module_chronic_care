class Clinic < ActiveRecord::Base
	
	def self.overview(activities)
		tasks = {}
		
				activities.each do |activity|
						total = Encounter.find_by_sql("SELECT DISTINCT(COUNT(patient_id)) as total FROM encounter
																		WHERE encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = '#{self.check_activity(activity)}')").first.total# rescue ""
						
            tasks[activity] = total
				end
		return tasks
	end

	def self.overview_this_year(activities)
		tasks = {}
				current_year = "#{Date.today.year}-01-01".to_date
				activities.each do |activity|
						total = Encounter.find_by_sql("SELECT DISTINCT(count(patient_id)) as patient_id FROM encounter
																		WHERE DATE(encounter_datetime) >= '#{current_year}' AND encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = '#{self.check_activity(activity)}')").first.patient_id rescue 0
						tasks[activity] = total
				end
		return tasks
	end

	def self.overview_today(activities)
		tasks = {}
				current_year = Date.today
				activities.each do |activity|

						total = Encounter.find_by_sql("SELECT DISTINCT(count(patient_id)) as patient_id FROM encounter
																		WHERE DATE(encounter_datetime) = '#{current_year}' AND encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = '#{self.check_activity(activity)}')").first.patient_id rescue 0
						
            tasks[activity] = total
				end
		return tasks
	end

	def self.overview_me(activities, user)
		tasks = {}
		current_year = Date.today
		activities.each do |activity|
				total = Encounter.find_by_sql("SELECT DISTINCT(count(patient_id)) as patient_id FROM encounter
													WHERE DATE(encounter_datetime) = '#{current_year}' AND provider_id = '#{user}' AND encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = '#{self.check_activity(activity)}')").first.patient_id rescue 0
			
        tasks[activity] = total
		end
		return tasks
	end

	def self.total_in_program(program_id)
		total = PatientProgram.find_by_sql("SELECT distinct(patient_id) as patient_id
													 FROM patient_program WHERE program_id = '#{program_id}'"
													)
		return total
	end

private
	def self.check_activity(task)
		 task = "UPDATE HIV STATUS" if task == "HIV STATUS"
		 task = "FAMILY MEDICAL HISTORY" if task == "FAMILY HISTORY"
		 task = "DIABETES HYPERTENSION INITIAL VISIT" if task == "CLINIC VISIT"
		 task = "UPDATE OUTCOME" if task == "OUTCOME"
		 return task
	end
end
