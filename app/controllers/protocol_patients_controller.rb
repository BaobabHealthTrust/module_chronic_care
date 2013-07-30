
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
    if current_program == "EPILEPSY PROGRAM"
      render :template => "/protocol_patients/epilepsy_diagnosis"
    end

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
    if current_program == "EPILEPSY PROGRAM"
      @sugar = ["FASTING BLOOD SUGAR", "RANDOM BLOOD SUGAR"]
    else
      @cholesterol = ["FASTING BLOOD SUGAR", "RANDOM BLOOD SUGAR", "CREATININE", "HbA1c"]

      @sugar = ["CHOLESTEROL FASTING", "CHOLESTEROL NOT FASTING", "CREATININE"]

      @cholesterol = treatments_list - @cholesterol

      @sugar = treatments_list - @sugar

      @generic = treatments_list - (@sugar + @cholesterol)
    end

    @current_program = current_program

	end

	def vitals
    current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
    @patient = Patient.find(params[:patient_id]) #rescue nil
    
    redirect_to '/encounters/no_patient' and return if @patient.blank?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = User.find(params[:user_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @user.nil?

    concept = ConceptName.find_by_sql("select concept_id from concept_name where name = 'height (cm)' and voided = 0").first.concept_id


    @current_hieght  = Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{@patient.id}'
                    AND DATE(obs_datetime) <= '#{current_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first rescue 0

   @current_hieght = @current_hieght.value_numeric.to_i rescue @current_hieght.value_text.to_i rescue nil
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
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'waist circumference' LIMIT 1) AND voided = 0
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1").first.value_numeric rescue nil
    @diabetic = ConceptName.find_by_concept_id(Vitals.get_patient_attribute_value(@patient, "Patient has Diabetes")).name rescue "unknown"


    @bmi = Observation.find_by_sql("SELECT * from obs
                   WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Body mass index, measured' LIMIT 1) AND voided = 0
                   AND voided = 0 AND person_id = #{@patient.id} ORDER BY obs_datetime DESC LIMIT 1")
    @bmi = @bmi.first.value_text.to_i rescue @bmi.first.value_numeric rescue 0

    @treatements_list = ["Heart disease", "Stroke", "TIA", "Diabetes", "Kidney Disease"]

      @treatements_list.delete_if {|var| var == "Diabetes"} if @diabetic.upcase == "YES"
    @current_program = current_program
    if current_program == "HYPERTENSION PROGRAM"
      if @bmi < 25 and @circumference < 90
        @task = "disable" 
      end
    end
	end

	def complications

    @patient = Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = User.find(params[:user_id]) rescue nil?
     @treatements_list = ["Amputation", "Stroke", "Myocardial injactia(MI)", "Creatinine", "Funduscopy","Shortness of breath","Oedema","CVA", "Peripheral nueropathy", "Foot ulcers", "Impotence", "Others"]

    redirect_to '/encounters/no_patient' and return if @user.nil?
    current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
	  enc = check_encounter(@patient, "lab results", current_date ).to_s
    
    @treatements_list.delete_if {|var| var == "Oedema"} if ! enc.match(/Blood Sugar Test Type:  Fasting/)
    @treatements_list.delete_if {|var| var == "Shortness of breath"} if ! enc.match(/Blood Sugar Test Type:  Random/)
    @treatements_list.delete_if {|var| var == "Funduscopy"} if ! enc.match(/Cholesterol Test Type:  Fasting/)
    @treatements_list.delete_if {|var| var == "Creatinine"} if ! enc.match(/Cholesterol Test Type:  Not Fasting/)
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
	
    @first_vist = is_first_hypertension_clinic_visit(@patient.id)

    if @cholesterol_value == 0
      flash[:notice] = "No Cholesterol Value, please capture vitals."
      redirect_to "/protocol_patients/vitals?patient_id=#{@patient.id}&user_id=#{@user["user_id"]}" and return
    end
	end

	def clinic_visit

    current_date = (!session[:datetime].nil? ? session[:datetime].to_date : Date.today)
    @patient = Patient.find(params[:patient_id]) rescue nil

    redirect_to '/encounters/no_patient' and return if @patient.nil?

    if params[:user_id].nil?
      redirect_to '/encounters/no_user' and return
    end

    @user = User.find(params[:user_id]) rescue nil?

    redirect_to '/encounters/no_patient' and return if @user.nil?

    @diabetic = Vitals.current_encounter(@patient, "assessment", "Patient has Diabetes") rescue []
	
    @current_program = current_program
    #@occupation = Vitals.occupation(@patient)

		if @current_program == "EPILEPSY PROGRAM"
      @regimen_concepts = MedicationService.hypertension_dm_drugs
      @first_visit = is_first_epilepsy_clinic_visit(@patient.id)
      @mrdt = Vitals.current_vitals(@patient, "RDT or blood smear positive for malaria") rescue nil
      unless @mrdt.blank?
        @mrdt = @mrdt.value_text.upcase rescue ConceptName.find_by_concept_id(@mrdt.value_coded).name.upcase
      end
      
      if @first_visit == false
        concept = ConceptName.find_by_name('Patient in active seizure').concept_id
        @in_seizure  = Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{@patient.id}'
                    AND DATE(obs_datetime) = '#{current_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first rescue 0
        
        @in_seizure = @in_seizure.value_text.upcase rescue ConceptName.find_by_concept_id(@in_seizure.value_coded).name.upcase rescue nil
        #raise @in_seizure.to_yaml
        #@in_seizure = Vitals.todays_vitals(Patient.find(params[:patient_id]), "Patient in active seizure")
        #@in_seizure = @in_seizure.value_text.upcase rescue ConceptName.find_by_concept_id(@in_seizure.value_coded).name.upcase rescue nil
      end
      render :template => "/protocol_patients/epilepsy_clinic_visit"
		end
		@first_visit = is_first_hypertension_clinic_visit(@patient.id) unless current_program == "EPILEPSY PROGRAM"
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

    @current_program = current_program

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
		 occupation_attribute = PersonAttributeType.find_by_name("Occupation")
     @person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", @patient.person.id, occupation_attribute.person_attribute_type_id]).value rescue "Unknown"
     @person_attribute = "<span>   :Patient occupation is " + @person_attribute + "</span>"
    @current_program = current_program
	end

  def check_encounter(patient, enc, current_date = Date.today)
    Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  current_date.to_date.to_date, patient.id,EncounterType.find_by_name(enc).id])
  end
end
