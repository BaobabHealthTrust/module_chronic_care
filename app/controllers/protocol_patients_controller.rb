
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

	def treatment

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
	

	end

	def vitals

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
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_coded

  @smoking_status = ConceptName.find_by_concept_id(status).name rescue "Unknown"

  @systolic_value = Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'systolic blood pressure' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue 0

  cholesterol_value = Observation.find_by_sql("SELECT * from obs
          WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'cholesterol test type' LIMIT 1)
          AND value_coded = (SELECT concept_id FROM concept_name WHERE name = 'fasting' LIMIT 1)
          AND voided = 0
          AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.obs_id rescue nil

  @cholesterol_value = Observation.find(:all, :conditions => ['obs_group_id = ?', cholesterol_value]).first.value_numeric.to_i


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
	end
end
