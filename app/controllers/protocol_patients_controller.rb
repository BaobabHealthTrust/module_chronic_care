
class ProtocolPatientsController < ApplicationController

	def hiv_status

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def asthma_measure
	@condition = []
	@familyhistory = []
	expected = ""
	predicted = ""
	current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?

	observation = Observation.find(:all,
		:conditions => ["encounter_id = ?", Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  current_date, @patient.id,EncounterType.find_by_name("Vitals").id]).encounter_id])
	#raise observation.to_s.to_yaml
	observation.each {|obs|
		value = ConceptName.find_by_concept_id(obs.value_coded).name if !obs.value_coded.blank?
		value = obs.value_numeric.to_i if !obs.value_numeric.blank?
		value = obs.value_text if !obs.value_text.blank?
		value = obs.value_datetime if !obs.value_datetime.blank?
		if obs.concept.fullname == "PEAK FLOW PREDICTED"
			value = value.to_i 
			predicted = value
		end
		expected = value.to_i if obs.concept.fullname.upcase == "PEAK FLOW"

		asthma_values = ["PEAK FLOW PREDICTED","PEAK FLOW", "BODY MASS INDEX, MEASURED","RESPIRATORY RATE", "CARDIOVASCULAR SYSTEM DIAGNOSIS"]
		next if !asthma_values.include?(obs.concept.fullname.upcase)
	 @condition.push("#{obs.concept.fullname.humanize} : #{value}")
	}
	@sthmatic = ""
	if expected < predicted
		@sthmatic = "yes"
		@condition.push('<i style="color: #B8002E">Expiratory measurement below normal : Possibly indicate obstructed airways</i>')
	end
	observation = Observation.find(:all,
		:conditions => ["encounter_id = ?", Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  current_date, @patient.id,EncounterType.find_by_name("FAMILY MEDICAL HISTORY").id]).encounter_id])
	
	@estimatedvalue = []
	observation.each {|obs|
		value = ConceptName.find_by_concept_id(obs.value_coded).name if !obs.value_coded.blank?
		value = obs.value_numeric.to_i if !obs.value_numeric.blank?
		value = obs.value_text if !obs.value_text.blank?
		value = obs.value_datetime if !obs.value_datetime.blank?
		asthma_values = ["HYPERTENSION", "ASTHMA"]
		if asthma_values.include?(obs.concept.fullname.upcase)
			@familyvalue = value.to_i if obs.concept.fullname.upcase == "ASTHMA"
			@estimatedvalue.push("#{obs.concept.fullname.humanize}" + 'in percentage : <i style="color: #B8002E">' + "#{value.to_i}" + '</i>')
			next
		end
	 @familyhistory.push("#{obs.concept.fullname.humanize} : #{value}")
	}
	@familyhistory +=  @estimatedvalue
	end

	def medical_history

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?
	@regimen_concepts = MedicationService.hypertension_dm_drugs

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def treatment
	 @current_program = current_program
	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def lab_results

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	treatments_list = get_global_property_value("lab_results").split(";") rescue ""

	@cholesterol = ["FASTING BLOOD SUGAR", "RANDOM BLOOD SUGAR", "CREATININE", "HbA1c"]
	
	@sugar = ["CHOLESTEROL FASTING", "CHOLESTEROL NOT FASTING", "CREATININE"]
	
	@cholesterol = treatments_list - @cholesterol

  @sugar = treatments_list - @sugar

	@generic = treatments_list - (@sugar + @cholesterol)

	end

	def vitals

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	@current_hieght = Vitals.get_patient_attribute_value(@patient, "current_height")
	@treatements_list = get_global_property_value("vitals").split(";") rescue ""

	end

	def update_outcome

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?


	end

	def outcomes

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def general_health

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?

	@regimen_concepts = MedicationService.hypertension_dm_drugs

  @circumference = Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Head circumference' LIMIT 1) AND voided = 0
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue nil
	@diabetic = ConceptName.find_by_concept_id(Vitals.get_patient_attribute_value(@patient, "Patient has Diabetes")).name rescue []

	 @treatements_list = ["Heart disease", "Stroke", "TIA", "Diabetes", "Kidney Disease"]

	 @treatements_list.delete_if {|var| var == "Diabetes"} if @diabetic.upcase == "YES"

	end

	def complications

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def assessment

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?

	@diabetic = ConceptName.find_by_concept_id(Vitals.get_patient_attribute_value(@patient, "Patient has Diabetes")).name rescue []

	 status = Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'current smoker' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_coded rescue 0

	
  @smoking_status = ConceptName.find_by_concept_id(status).name rescue "Unknown"

  @systolic_value = Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'systolic blood pressure' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

  cholesterol_value = Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'cholesterol test type' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.obs_id rescue nil

  @cholesterol_value = Observation.find(:all, :conditions => ['obs_group_id = ?', cholesterol_value]).first.value_numeric.to_i rescue 0
	if status == 0
		flash[:notice] = "No smoking status, please capture social history."
		redirect_to "/protocol_patients/social_history?patient_id=#{@patient.id}&user_id=#{@user["user_id"]}" and return
	end

	if @systolic_value == 0
		flash[:notice] = "No Systolic Blood Pressure status, please vitals."
		redirect_to "/protocol_patients/vitals?patient_id=#{@patient.id}&user_id=#{@user["user_id"]}" and return
	end
	
  @first_vist = is_first_hypertension_clinic_visit(@person.id)

	if @cholesterol_value == 0
		flash[:notice] = "No Cholesterol Value, please capture vitals."
		redirect_to "/protocol_patients/vitals?patient_id=#{@patient.id}&user_id=#{@user["user_id"]}" and return
	end
	end

	def clinic_visit

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?

	@diabetic = Vitals.current_encounter(@patient, "assessment", "Patient has Diabetes") rescue []
	
	@first_visit = is_first_hypertension_clinic_visit(@patient.id)
	
	@current_program = current_program

	end

	def family_history
			@patient = Patient.find(params[:patient_id]) rescue nil

			redirect_to '/encounters/no_patient' and return if @patient.nil?

			if params[:user_id].nil?
			redirect_to '/encounters/no_user' and return
			end

			@user = User.find(params[:user_id]) rescue nil?

			redirect_to '/encounters/no_patient' and return if @user.nil?

			@diabetic = Vitals.current_encounter(@patient, "assessment", "Patient has Diabetes") rescue []

			@first_visit = is_first_hypertension_clinic_visit(@patient.id)

	end

	def social_history
			@patient = Patient.find(params[:patient_id]) rescue nil

			redirect_to '/encounters/no_patient' and return if @patient.nil?

			if params[:user_id].nil?
			redirect_to '/encounters/no_user' and return
			end

			@user = User.find(params[:user_id]) rescue nil?

			redirect_to '/encounters/no_patient' and return if @user.nil?

			@diabetic = Vitals.current_encounter(@patient, "assessment", "Patient has Diabetes") rescue []

			@first_visit = is_first_hypertension_clinic_visit(@patient.id)
			
			@current_program = current_program
			#raise @current_program.to_yaml
	end
end
