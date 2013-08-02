
class PatientsController < ApplicationController
  before_filter :find_patient

  def show
    @patient = Patient.find(params[:id] || params[:patient_id]) rescue nil

    if @patient.nil?
      redirect_to "/encounters/no_patient" and return
    end

    if params[:user_id].nil?
      redirect_to "/encounters/no_user" and return
    end

    @user = User.find(params[:user_id]) rescue nil
    
    redirect_to "/encounters/no_user" and return if @user.nil?

    @task = TaskFlow.new(params[:user_id], @patient.id)
		
    @links = {}

		@project = get_global_property_value("project.name") rescue "Unknown"
		current_user_activities = UserProperty.find_by_user_id_and_property(params[:user_id],
      "#{@project.downcase.gsub(/\s/, ".")}.activities").property_value.split(",").collect{|a| a.downcase} rescue []

    @task.tasks.each{|task|
			next if ! current_user_activities.include?(task.downcase)
      @links[task.titleize] = "/protocol_patients/#{task.gsub(/\s/, "_")}?patient_id=#{@patient.id}&user_id=#{params[:user_id]}"
			@links[task.titleize] = "/patients/treatment_dashboard/#{@patient.id}?user_id=#{params[:user_id]}" if task.downcase == "treatment"
    }

    @demographics_url = get_global_property_value("patient.registration.url") rescue nil

    if !@demographics_url.nil?
      @demographics_url = @demographics_url + "/demographics/#{@patient.id}?user_id=#{@user.id}&ext=true"
    end
		@demographics_url = "http://" + @demographics_url if !@demographics_url.match(/http:/)
	
		if current_program == "ASTHMA PROGRAM"
			@task.asthma_next_task rescue ""
		elsif current_program == "EPILEPSY PROGRAM"
			@task.epilepsy_next_task rescue ""
		else
			@task.next_task rescue ""
		end

		@disable = params[:disable] rescue ""

  end

  def current_visit
    @retrospective = session[:datetime]
		@retrospective = Time.now if session[:datetime].blank?

    
    @patient = Patient.find(params[:id] || params[:patient_id]) rescue nil

    ProgramEncounter.current_date = @retrospective

    @programs = @patient.program_encounters.find(:all, :conditions => ["DATE(date_time) = ?", @retrospective.to_date],
                                                 :order => ["date_time DESC"]).collect{|p|

      [
        p.id,
        p.to_s,
        p.program_encounter_types.collect{|e|
          [
            e.encounter_id, e.encounter.type.name,
            e.encounter.encounter_datetime.strftime("%H:%M"),
            e.encounter.creator
          ]
        },
        p.date_time.strftime("%d-%b-%Y")
      ]
    } if !@patient.nil?

    render :layout => false
  end

  def visit_history
    @patient = Patient.find(params[:id] || params[:patient_id]) rescue nil

    @programs = @patient.program_encounters.find(:all, :order => ["date_time DESC"]).collect{|p|

      [
        p.id,
        p.to_s,
        p.program_encounter_types.collect{|e|
          [
            e.encounter_id, e.encounter.type.name,
            e.encounter.encounter_datetime.strftime("%H:%M"),
            e.encounter.creator
          ]
        },
        p.date_time.strftime("%d-%b-%Y")
      ]
    } if !@patient.nil?

    # raise @programs.inspect

    render :layout => false
  end

  def demographics
    @patient = Patient.find(params[:id] || params[:patient_id]) rescue nil

    if @patient.nil?
      redirect_to "/encounters/no_patient" and return
    end

    if params[:user_id].nil?
      redirect_to "/encounters/no_user" and return
    end

    @user = User.find(params[:user_id]) rescue nil

    redirect_to "/encounters/no_user" and return if @user.nil?

  end

  def mastercard
    @type = params[:type]

    if session[:from_report].to_s == "true"
			@from_report = true
			session[:from_report] = false
    end
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]

    #if params[:show_mastercard_counter].to_s == "true" && !params[:current].blank?
    @show_mastercard_counter = true
    session[:mastercard_counter] = params[:current].to_i - 1
    # @patient_id = session[:mastercard_ids][session[:mastercard_counter]]

    @prev_button_class = "yellow"
    @next_button_class = "yellow"

    # if params[:current].to_i ==  1
    #   @prev_button_class = "gray"
    #elsif params[:current].to_i ==  session[:mastercard_ids].length
    #  @next_button_class = "gray"
    #end

    #elsif params[:patient_id].blank?
    #  @patient_id = session[:mastercard_ids][session[:mastercard_counter]]

    #elsif session[:mastercard_ids].length.to_i != 0
    #  @patient_id = params[:patient_id]

    #else
    # @patient_id = params[:patient_id]

    #end

    unless params.include?("source")
      @source = params[:source] rescue nil
    else
      @source = nil
    end

    render :layout => "application"

  end

  def mastercard_printable
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false

    if params[:patient_id].blank?

      @show_mastercard_counter = true

      if !params[:current].blank?
        session[:mastercard_counter] = params[:current].to_i - 1
      end

      @prev_button_class = "yellow"
      @next_button_class = "yellow"
      if params[:current].to_i ==  1
        @prev_button_class = "gray"
      elsif params[:current].to_i ==  session[:mastercard_ids].length
        @next_button_class = "gray"
      else

      end
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
      @data_demo = mastercard_demographics(Patient.find(@patient_id))
      @visits = visits(Patient.find(@patient_id))
      @patient_art_start_date = PatientService.patient_art_start_date(@patient_id)
      # elsif session[:mastercard_ids].length.to_i != 0
      #  @patient_id = params[:patient_id]
      #  @data_demo = mastercard_demographics(Patient.find(@patient_id))
      #  @visits = visits(Patient.find(@patient_id))
    else
      @patient_id = params[:patient_id]
      @patient_art_start_date = PatientService.patient_art_start_date(@patient_id) rescue
      @data_demo = mastercard_demographics(Patient.find(@patient_id))
			#raise @data_demo.eptb.to_yaml
      @visits = visits(Patient.find(@patient_id))
    end

    @visits.keys.each do|day|
			@age_in_months_for_days[day] = PatientService.age_in_months(@patient.person, day.to_date)
    end rescue nil

    render :layout => false
  end

  def print_patient_mastercard
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false

    if params[:patient_id].blank?

      @show_mastercard_counter = true

      if !params[:current].blank?
        session[:mastercard_counter] = params[:current].to_i - 1
      end

     # @prev_button_class = "yellow"
      #@next_button_class = "yellow"
      #if params[:current].to_i ==  1
      #  @prev_button_class = "gray"
      #elsif params[:current].to_i ==  session[:mastercard_ids].length
      #  @next_button_class = "gray"
      #else

      #end
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
      @data_demo = mastercard_demographics(Patient.find(@patient_id))
      @visits = visits(Patient.find(@patient_id))
      @patient_art_start_date = PatientService.patient_art_start_date(@patient_id)
      # elsif session[:mastercard_ids].length.to_i != 0
      #  @patient_id = params[:patient_id]
      #  @data_demo = mastercard_demographics(Patient.find(@patient_id))
      #  @visits = visits(Patient.find(@patient_id))
    else
      @patient_id = params[:patient_id]
      @patient_art_start_date = PatientService.patient_art_start_date(@patient_id) rescue
      @data_demo = mastercard_demographics(Patient.find(@patient_id))
			#raise @data_demo.eptb.to_yaml
      @visits = visits(Patient.find(@patient_id))
    end

    @visits.keys.each do|day|
			@age_in_months_for_days[day] = PatientService.age_in_months(@patient.person, day.to_date)
    end rescue nil

    render :layout => false
  end




  def print_mastercard

    if @patient
=begin
      t1 = Thread.new{
        Kernel.system "htmldoc --webpage --landscape --linkstyle plain --left 1cm --right 1cm --top 1cm --bottom 1cm -f /tmp/output-" +
          @user['user_id'].to_s + ".pdf http://" + request.env["HTTP_HOST"] + "\"/patients/mastercard_printable?patient_id=" +
          @patient.id.to_s + "\"&user_id=" + @user['user_id'] + "\"\n"
      }
=end
      current_printer = CoreService.get_global_property_value("facility.printer").split(":")[1] rescue []
   
      t1 = Thread.new{
        Kernel.system "wkhtmltopdf --orientation landscape --copies 2 --margin-top 0 --margin-bottom 0 -s A4 http://" +
          request.env["HTTP_HOST"] + "\"/patients/print_patient_mastercard/" +
          "?patient_id=#{@patient.id}" + "\" /tmp/output-#{@patient.id}" + ".pdf \n"

      }


        file = "/tmp/output-#{@patient.id}" + ".pdf"

        t2 = Thread.new{
          sleep(3)
          print(file, current_printer)
        }
    end
    
    redirect_to request.request_uri.to_s.gsub('print_mastercard', 'mastercard') and return
  end

def print(file_name, current_printer)
    sleep(3)
    if (File.exists?(file_name))
     Kernel.system "lp -o sides=two-sided-long-edge -o fitplot #{(!current_printer.blank? ? '-d ' + current_printer.to_s : "")} #{file_name}"
    else
      print(file_name)
    end
end

  def mastercard_demographics(patient_obj)
    
  	#patient_bean = PatientService.get_patient(patient_obj.person)
    visits = Mastercard.new()
    visits.zone = get_global_property_value("facility.zone.name") rescue "Unknown"
    visits.clinic = get_global_property_value("facility.name") rescue "Unknown"
    visits.district = get_global_property_value("facility.district") rescue "Unknown"
    visits.patient_id = patient_obj.id
    visits.arv_number = patient_obj.arv_number rescue nil
    visits.address = patient_obj.address
    visits.national_id = patient_obj.national_id
    visits.name = patient_obj.name rescue nil
    visits.sex = patient_obj.gender
    visits.age = patient_obj.age
    visits.birth_date = patient_obj.person.birthdate rescue patient_obj.person.birthdate_estimated rescue nil
    visits.occupation = Vitals.occupation(patient_obj).value rescue "Not specified"
    visits.landmark = patient_obj.person.addresses.first.address1 rescue ""
    visits.init_wt = Vitals.get_patient_attribute_value(patient_obj, "initial_weight")
    visits.init_ht = Vitals.get_patient_attribute_value(patient_obj, "initial_height")
    visits.agrees_to_followup = patient_obj.person.observations.recent(1).question("Agrees to followup").all rescue nil
    visits.agrees_to_followup = visits.agrees_to_followup.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_date = patient_obj.person.observations.recent(1).question("Confirmatory HIV test date").all rescue nil
    visits.hiv_test_date = visits.hiv_test_date.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_location = patient_obj.person.observations.recent(1).question("Confirmatory HIV test location").all rescue nil
    location_name = Location.find_by_location_id(visits.hiv_test_location.to_s.split(':')[1].strip).name rescue nil
    visits.hiv_test_location = location_name rescue nil
    visits.appointment_date = current_vitals(patient_obj,"APPOINTMENT DATE").to_s
    visits.history_asthma = current_vitals(patient_obj,"Has the family a history of asthma?").to_s.split(':')[1].match(/yes/i) rescue nil
    ! visits.history_asthma.blank? ? visits.history_asthma = "Y" : visits.history_asthma = "N"
    visits.guardian = Vitals.guardian(patient_obj) rescue nil
    visits.reason_for_art_eligibility = PatientService.reason_for_art_eligibility(patient_obj) rescue nil
    visits.transfer_in = current_vitals(patient_obj, "TYPE OF PATIENT").to_s.split(":")[1].match(/transfer in/i) rescue nil #pb: bug-2677 Made this to use the newly created patient model method 'transfer_in?'
    ! visits.transfer_in.blank? ? visits.transfer_in = 'NO' : visits.transfer_in = 'YES'

    transferred_out_details = Observation.find(:last, :conditions =>["concept_id = ? and person_id = ?", ConceptName.find_by_name("TRANSFER OUT TO").concept_id,patient_obj.id]) rescue ""

		visits.transferred_out_to = transferred_out_details.value_text if transferred_out_details
		visits.transferred_out_date = transferred_out_details.obs_datetime if transferred_out_details

		visits.art_start_date = PatientService.patient_art_start_date(patient_obj.id).strftime("%d-%B-%Y") rescue nil

    visits.transfer_in_date = patient_obj.person.observations.recent(1).question("TYPE OF PATIENT").all.collect{|o|
			o.obs_datetime if o.answer_string.match(/transfer in/i)}.last rescue nil

    regimens = {}
    regimen_types = ['FIRST LINE ANTIRETROVIRAL REGIMEN','ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN','SECOND LINE ANTIRETROVIRAL REGIMEN']
    regimen_types.map do | regimen |
      concept_member_ids = ConceptName.find_by_name(regimen).concept.concept_members.collect{|c|c.concept_id}
      case regimen
			when 'FIRST LINE ANTIRETROVIRAL REGIMEN'
				regimens[regimen] = concept_member_ids
			when 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN'
				regimens[regimen] = concept_member_ids
			when 'SECOND LINE ANTIRETROVIRAL REGIMEN'
				regimens[regimen] = concept_member_ids
      end
    end

    first_treatment_encounters = []
    encounter_type = EncounterType.find_by_name('DISPENSING').id
    amount_dispensed_concept_id = ConceptName.find_by_name('Amount dispensed').concept_id
    regimens.map do | regimen_type , ids |
      encounter = Encounter.find(:first,
				:joins => "INNER JOIN obs ON encounter.encounter_id = obs.encounter_id",
				:conditions =>["encounter_type=? AND encounter.patient_id = ? AND concept_id = ?
                                 AND encounter.voided = 0",encounter_type , patient_obj.id , amount_dispensed_concept_id ],
				:order =>"encounter_datetime")
      first_treatment_encounters << encounter unless encounter.blank?
    end

    visits.first_line_drugs = []
    visits.alt_first_line_drugs = []
    visits.second_line_drugs = []

    first_treatment_encounters.map do | treatment_encounter |
      treatment_encounter.observations.map{|obs|
        next if not obs.concept_id == amount_dispensed_concept_id
        drug = Drug.find(obs.value_drug) if obs.value_numeric > 0
        next if obs.value_numeric <= 0
        drug_concept_id = drug.concept.concept_id
        regimens.map do | regimen_type , concept_ids |
          if regimen_type == 'FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_line_regimen =  PatientService.date_antiretrovirals_started(patient_obj) #treatment_encounter.encounter_datetime.to_date
            visits.first_line_drugs << drug.concept.shortname
            visits.first_line_drugs = visits.first_line_drugs.uniq rescue []
          elsif regimen_type == 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_first_alt_line_regimen = PatientService.date_antiretrovirals_started(patient_obj) #treatment_encounter.encounter_datetime.to_date
            visits.alt_first_line_drugs << drug.concept.shortname
            visits.alt_first_line_drugs = visits.alt_first_line_drugs.uniq rescue []
          elsif regimen_type == 'SECOND LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
            visits.date_of_second_line_regimen = treatment_encounter.encounter_datetime.to_date
            visits.second_line_drugs << drug.concept.shortname
            visits.second_line_drugs = visits.second_line_drugs.uniq rescue []
          end
        end
      }.compact
    end

    ans = ["Extrapulmonary tuberculosis (EPTB)","Pulmonary tuberculosis within the last 2 years","Pulmonary tuberculosis (current)","Kaposis sarcoma","Pulmonary tuberculosis"]
    staging_ans = patient_obj.person.observations.recent(1).question("WHO STAGES CRITERIA PRESENT").all
    if staging_ans.blank?
      staging_ans = patient_obj.person.observations.recent(1).question("WHO STG CRIT").all
    end
    #raise current_vitals(patient_obj, "cardiovascular complications present").to_yaml

    visits.diagnosis_asthma = current_encounter(patient_obj, "ASTHMA MEASURE", "ASTHMA").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.diagnosis_asthma.blank? ? visits.diagnosis_asthma = "Y" : visits.diagnosis_asthma = "N"

    visits.diagnosis_stroke = current_encounter(patient_obj, "GENERAL HEALTH", "CHRONIC DISEASE").to_s.match(/Acute cerebrovascular attack/i) rescue nil
    ! visits.diagnosis_stroke.blank? ? visits.diagnosis_stroke = "Y" : visits.diagnosis_stroke = "N"
  
    visits.smoking = current_vitals(patient_obj, "current smoker").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.smoking.blank? ? visits.smoking = "Y" : visits.smoking = "N"

    visits.alcohol = current_vitals(patient_obj, "Does the patient drink alcohol?").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.alcohol.blank? ? visits.alcohol = 'Y' : visits.alcohol = 'N'

    visits.dm = current_vitals(patient_obj, "diabetes family history").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.dm.blank? ? visits.dm = "Y" : visits.dm = "N"

    visits.htn = current_vitals(patient_obj, "Does the family have a history of hypertension?").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.htn.blank? ? visits.htn = "Y" : visits.htn = "N"

    visits.tb_within_last_two_yrs = current_vitals(patient_obj, "tb in previous two years").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.tb_within_last_two_yrs.blank? ? visits.tb_within_last_two_yrs = "Y" : visits.tb_within_last_two_yrs = "N"

    visits.asthma = current_encounter(patient_obj, "MEDICAL HISTORY", "asthma").to_s.split(":")[1].asthma.match(/yes/i) rescue nil
    visits.asthma == "yes" ? visits.asthma = "Y" : visits.asthma = "N"

    visits.stroke = current_vitals(patient_obj, "ever had a stroke").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.stroke.blank? ? visits.stroke = "Y" : visits.stroke = "N"

    visits.hiv_status = current_encounter(patient_obj, "UPDATE HIV STATUS", "HIV STATUS").to_s.split(":")[1].match(/positive/i) rescue nil
    ! visits.hiv_status.blank? ? visits.hiv_status = "R" : visits.hiv_status = "NR"

    visits.art_status = current_vitals(patient_obj, "on art").to_s.split(":")[1].match(/yes/i) rescue nil
    ! visits.art_status.blank? ? visits.art_status = "Y" : visits.art_status = "N"

    visits.oedema = current_encounter(patient_obj, "COMPLICATIONS", "oedema") rescue []
    ! visits.oedema.blank? ? visits.oedema = "Y Date: #{visits.oedema.to_s.split(":")[1]}" : visits.oedema = "N"

    visits.cardiac = current_encounter(patient_obj, "COMPLICATIONS", "Cardiac") rescue []
    ! visits.cardiac.blank? ? visits.cardiac = "Y Date: #{visits.cardiac.to_s.split(":")[1]}" : visits.cardiac = "N"

    visits.mi = current_encounter(patient_obj, "COMPLICATIONS", "myocardial injactia") rescue []
    ! visits.mi.blank? ? visits.mi = "Y Date: #{visits.mi.to_s.split(":")[1]}" : visits.mi = "N"

    visits.funduscopy = current_encounter(patient_obj, "COMPLICATIONS", "fundus") rescue []
    ! visits.funduscopy.blank? ? visits.funduscopy = "Y Date: #{visits.funduscopy.to_s.split(":")[1]}" : visits.funduscopy = "N"

    visits.creatinine = current_encounter(patient_obj, "COMPLICATIONS", "Creatinine") rescue []
    ! visits.creatinine.blank? ? visits.creatinine = "Y Date: #{visits.creatinine.to_s.split(":")[1]}" : visits.creatinine = "N"

    visits.comp_stroke = current_encounter(patient_obj, "COMPLICATIONS", "stroke") rescue []
    ! visits.comp_stroke.blank? ? visits.creatinine = "Y" : visits.comp_stroke = "N"

    chronic_diseases = current_encounter(patient_obj, "GENERAL HEALTH", "CHRONIC DISEASE").to_s.match(/Chronic disease:   TIA/i) rescue nil
    ! chronic_diseases.blank? ? visits.tia = "Y" : visits.tia = "N"

    visits.amputation = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:  Amputation/i) rescue nil
    ! visits.amputation.blank? ? visits.amputation = "Y" : visits.amputation = "N"

    #raise Vitals.current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.to_yaml
    visits.neuropathy = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:   Peripheral nueropathy/i) rescue nil
    ! visits.neuropathy.blank? ? visits.neuropathy = "Y" : visits.neuropathy = "N"

    visits.foot_ulcers = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:   Foot ulcers/i) rescue nil
    ! visits.foot_ulcers.blank? ? visits.foot_ulcers = "Y" : visits.foot_ulcers = "N"

    visits.impotence = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:  Impotence/i) rescue nil
    ! visits.impotence.blank? ? visits.impotence = "Y" : visits.impotence = "N"

    visits.comp_other = current_encounter(patient_obj, "COMPLICATIONS", "COMPLICATIONS").to_s.match(/Complications:   Others/i) rescue nil
    ! visits.comp_other.blank? ? visits.comp_other = "Y" : visits.comp_other = "N"

    visits.diagnosis_dm = current_vitals(patient_obj, "Patient has Diabetes").to_s.match(/yes/i) rescue nil
    ! visits.diagnosis_dm.blank? ? visits.diagnosis_dm = "Y" : visits.diagnosis_dm = "N"

    visits.diagnosis_htn = current_vitals(patient_obj, "cardiovascular system diagnosis").to_s.match(/Hypertension /i) rescue nil

    ! visits.diagnosis_htn.blank? ? visits.diagnosis_htn = "Y" : visits.diagnosis_htn = "N"

    visits.diagnosis_dm_htn = "N"
    visits.diagnosis_dm_htn = "Y" if visits.diagnosis_htn = "Y" and visits.diagnosis_dm = "Y"

    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient_obj.id])

    visits.who_clinical_conditions = ""
    (hiv_staging.observations).collect do |obs|
      if CoreService.get_global_property_value('use.extended.staging.questions').to_s == 'true'
        name = obs.to_s.split(':')[0].strip rescue nil
        ans = obs.to_s.split(':')[1].strip rescue nil
        next unless ans.upcase == 'YES'
        visits.who_clinical_conditions = visits.who_clinical_conditions + (name) + "; "
      else
        name = obs.to_s.split(':')[0].strip rescue nil
        next unless name == 'WHO STAGES CRITERIA PRESENT'
        condition = obs.to_s.split(':')[1].strip.humanize rescue nil
        visits.who_clinical_conditions = visits.who_clinical_conditions + (condition) + "; "
      end
    end rescue []

    visits.cd4_count_date = nil ; visits.cd4_count = nil ; visits.pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name.downcase
			when 'cd4 count datetime'
				visits.cd4_count_date = obs.value_datetime.to_date
			when 'cd4 count'
				visits.cd4_count = "#{obs.value_modifier}#{obs.value_numeric.to_i}"
			when 'is patient pregnant?'
				visits.pregnant = obs.to_s.split(':')[1] rescue nil
			when 'lymphocyte count'
				visits.tlc = obs.answer_string
			when 'lymphocyte count date'
				visits.tlc_date = obs.value_datetime.to_date
      end
    end rescue []

    visits.tb_status_at_initiation = (!visits.tb_status.nil? ? "Curr" :
				(!visits.tb_within_last_two_yrs.nil? ? (visits.tb_within_last_two_yrs.upcase == "YES" ?
						"Last 2yrs" : "Never/ >2yrs") : "Never/ >2yrs"))

    hiv_clinic_registration = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV CLINIC REGISTRATION").id,patient_obj.id])

    (hiv_clinic_registration.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'Ever received ART?'
        visits.ever_received_art = obs.to_s.split(':')[1].strip rescue nil
      when 'Last ART drugs taken'
        visits.last_art_drugs_taken = obs.to_s.split(':')[1].strip rescue nil
      when 'Date ART last taken'
        visits.last_art_drugs_date_taken = obs.value_datetime.to_date rescue nil
      when 'Confirmatory HIV test location'
        visits.first_positive_hiv_test_site = obs.to_s.split(':')[1].strip rescue nil
      when 'ART number at previous location'
        visits.first_positive_hiv_test_arv_number = obs.to_s.split(':')[1].strip rescue nil
      when 'Confirmatory HIV test type'
        visits.first_positive_hiv_test_type = obs.to_s.split(':')[1].strip rescue nil
      when 'Confirmatory HIV test date'
        visits.first_positive_hiv_test_date = obs.value_datetime.to_date rescue nil
      end
    end rescue []

    visits
  end

  
  def calculate_bp(patient, visit_date)
    systolic = Vitals.todays_vitals(patient, "Systolic blood pressure", visit_date).value_numeric.to_i rescue 0
    diastolic = Vitals.todays_vitals(patient, "Diastolic blood pressure", visit_date).value_numeric.to_i rescue 0
    
    return "#{systolic}/#{diastolic}"
  end

  def number_of_booked_patients
    date = params[:date].to_date
    encounter_type = EncounterType.find_by_name('Kangaroo review visit') rescue nil
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id

    count = Observation.count(:all,
      :joins => "INNER JOIN encounter e USING(encounter_id)",:group => "value_datetime",
      :conditions =>["concept_id = ? AND encounter_type = ? AND value_datetime >= ? AND value_datetime <= ?",
        concept_id,encounter_type.id,date.strftime('%Y-%m-%d 00:00:00'),date.strftime('%Y-%m-%d 23:59:59')]) rescue nil

    count = count.values unless count.blank?
    count = '0' if count.blank?

    render :text => (count.first.to_i > 0 ? {params[:date] => count}.to_json : 0)
  end

	def confirm
		session_date = session[:datetime] || Date.today

		@current_location = params[:location_id]
		@current_user = User.find(@user["user_id"])
		
		@found_person_id = params[:found_person_id] || session[:location_id]
		@relation = params[:relation] rescue nil
		@person = Person.find(@found_person_id) rescue nil
		@task = TaskFlow.new(params[:user_id], @person.id) rescue nil
    concept_id = ConceptName.find_by_name("WEIGHT (KG)")
    @obs = Observations.find_by_sql("SELECT * FROM obs WHERE concept_id = #{concept_id}
                                    AND person_id = #{@person.id}")

		@next_task = @task.next_task.encounter_type.gsub('_',' ') if (current_program == "HYPERTENSION PROGRAM" || current_program.blank?) rescue nil
		@next_task = @task.asthma_next_task.encounter_type.gsub('_',' ') if current_program == "ASTHMA PROGRAM" rescue nil
		@next_task = @task.epilepsy_next_task.encounter_type.gsub('_',' ') if current_program == "EPILEPSY PROGRAM" rescue nil

		@current_task = @task.next_task if (current_program == "HYPERTENSION PROGRAM" || current_program.blank?) rescue nil
		@current_task = @task.asthma_next_task if current_program == "ASTHMA PROGRAM" rescue nil
		@current_task = @task.epilepsy_next_task if current_program == "EPILEPSY PROGRAM" rescue nil

		@arv_number = PatientService.get_patient_identifier(@person, 'ARV Number') rescue ""		
		@patient_bean = PatientService.get_patient(@person) rescue ""
		@location = Location.find(params[:location_id] || session[:location_id]).name rescue nil
		@conditions = []
		if current_program == "EPILEPSY PROGRAM"
      @conditions.push("Visit Type											:  First Vist") if  is_first_epilepsy_clinic_visit(@person.id) == true
      @conditions.push("Visit Type											:  Follow up visit") if  is_first_epilepsy_clinic_visit(@person.id) != true
      @conditions.push("Expected Appointment date: #{Vitals.get_patient_attribute_value(@person.patient, 'appointment date').to_date.strftime('%d/%m/%Y') rescue 'None'}") if  is_first_epilepsy_clinic_visit(@person.id) != true
		else
      @conditions.push("Visit Type											:  First Vist") if  is_first_hypertension_clinic_visit(@person.id) == true
      @conditions.push("Visit Type											:  Follow up visit") if  is_first_hypertension_clinic_visit(@person.id) != true

      risk = Vitals.current_encounter(@person.patient, "assessment", "assessment comments") rescue "Previous Hypetension Assessment : Not Available"
      @conditions.push("Expected Appointment date: #{Vitals.get_patient_attribute_value(@person.patient, 'appointment date').to_date.strftime('%d/%m/%Y') rescue 'None'}") if  is_first_hypertension_clinic_visit(@person.id) != true
      @conditions.push("#{risk} ")
      @conditions.push("Asthma Expected Peak Flow Rate  : #{Vitals.expectect_flow_rate(@person.patient)} Litres/Minute") if  is_first_hypertension_clinic_visit(@person.id) != true
		end
		render :layout => 'menu'
	end

  def treatment_dashboard
		@user = User.find(params[:user_id]) rescue nil
		@patient = Patient.find(params[:id]) rescue nil
		@dispense = CoreService.get_global_property_value('use_drug_barcodes_only')
	  #@patient_bean = PatientService.get_patient(@patient.person)
    @amount_needed = 0
    @amounts_required = 0

    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date]).each{|order|

      @amount_needed = @amount_needed + (order.drug_order.amount_needed.to_i rescue 0)

      @amounts_required = @amounts_required + (order.drug_order.total_required rescue 0)

    }

    @dispensed_order_id = params[:dispensed_order_id]
    #@reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient) rescue nil
    #@arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number') rescue nil

		@project = get_global_property_value("project.name") rescue "Unknown"
		
    render :template => 'dashboards/treatment_dashboard', :layout => false
  end

  def treatment
		@user = User.find(params[:user_id]) rescue nil
		@patient = Patient.find(params[:patient_id] || params[:id]) rescue nil
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date])
		
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		
    @restricted.each do |restriction|
      @prescriptions = restriction.filter_orders(@prescriptions)
    end

    @encounters = @patient.encounters.find_by_date(session_date)

    @transfer_out_site = nil

    @encounters.each do |enc|
      enc.observations.map do |obs|
				@transfer_out_site = obs.to_s if obs.to_s.include?('Transfer out to')
			end
    end
    #@reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    #@arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :template => 'dashboards/dispension_tab', :layout => false
  end

  def history_treatment
    @user = User.find(params[:user_id]) rescue nil
    @patient = Patient.find(params[:patient_id] || params[:id])
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ?",type.id,@patient.id])

    @historical = @patient.orders.historical.prescriptions.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @historical = restriction.filter_orders(@historical)
    end

    render :template => 'dashboards/treatment_tab', :layout => false
  end
	
	def patient_report
		@user = User.find(params[:user_id]) rescue nil
		@patient = Patient.find(params[:patient_id] || params[:id]) rescue nil
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date])

    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })

    @restricted.each do |restriction|
      @prescriptions = restriction.filter_orders(@prescriptions)
    end

    @encounters = @patient.encounters.find_by_date(session_date)

    @transfer_out_site = nil

    @encounters.each do |enc|
      enc.observations.map do |obs|
				@transfer_out_site = obs.to_s if obs.to_s.include?('Transfer out to')
			end
    end
		@sbp = current_vitals(@patient, "systolic blood pressure").value_numeric rescue 0
		@dbp = current_vitals(@patient, "diastolic blood pressure").value_numeric rescue 0

		@complications = Vitals.current_encounter(@patient, "complications", "complications") rescue []
								
		@diabetic = ConceptName.find_by_concept_id(Vitals.get_patient_attribute_value(@patient, "Patient has Diabetes")).name rescue []

		@risk = Vitals.current_encounter(@patient, "assessment", "assessment comments") rescue []

		#raise @prescriptions.to_yaml
		@programs = @patient.program_encounters.current.collect{|p|

      [
        p.id,
        p.to_s,
        p.program_encounter_types.collect{|e|
          [
            e.encounter_id, e.encounter.type.name,
            e.encounter.encounter_datetime.strftime("%H:%M"),
            e.encounter.creator
          ]
        },
        p.date_time.strftime("%d-%b-%Y")
      ]
    } if !@patient.nil?
    #@reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    #@arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')

    render :layout => false
  end

  def printouts
    @user = User.find(params[:user_id]) rescue nil
		@patient = Patient.find(params[:patient_id] || params[:id]) rescue nil
    render :layout => false
  end

	def hiv_status
		@user = User.find(params[:user_id]) rescue nil
		@patient = Patient.find(params[:patient_id] || params[:id]) rescue nil
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today

		@status = ConceptName.find_by_concept_id(Vitals.get_patient_attribute_value(@patient, "hiv")).name rescue []
  end

	def graph
    @currentWeight = params[:currentWeight]
		@estimated = params[:estimated]
		@expected = params[:expected]
    render :template => "graphs/#{params[:data]}", :layout => false
  end

	def number_of_booked_patients
		@user = User.find(params[:user_id]) rescue nil
		@patient = Patient.find(params[:patient_id] || params[:id]) rescue nil
		
    date = params[:date].to_date
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id

    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')

    appointments = Observation.find_by_sql("SELECT count(*) AS count FROM obs
      INNER JOIN encounter e USING(encounter_id) WHERE concept_id = #{concept_id}
      AND encounter_type = #{encounter_type.id} AND value_datetime >= '#{start_date}'
      AND value_datetime <= '#{end_date}' AND obs.voided = 0 GROUP BY value_datetime")
    count = appointments.first.count unless appointments.blank?
    count = '0' if count.blank?

    render :text => (count.to_i >= 0 ? {params[:date] => count}.to_json : 0)
  end

  def dashboard_print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{params[:id]}&user_id=#{params[:user_id]}", "/patients/show/#{params[:id]}&user_id=#{params[:user_id]}")
  end

	def visit_label
		session_date = session[:datetime].to_date rescue Date.today
		@patient = Patient.find(params[:patient_id])
		#raise @patient.to_yaml
    print_string = patient_visit_label(@patient, session_date) #rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

	def patient_visit_label(patient, date = Date.today)
    #result = Location.find(session[:location_id]).name.match(/outpatient/i)
		visit = visits(patient, date)[date] rescue {}

		return if visit.blank?
    visit_data = mastercard_visit_data(visit)

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    # label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient.name}(#{patient.gender})",25,60,0,3,1,1,false)
    #label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit.height.to_s + 'cm' if !visit.height.blank?}  #{visit.weight.to_s + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s if !visit.bmi.blank?}  #{'BP :' + visit_data['bp'] }",25,95,0,2,1,1,false)
    #label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("TB",110,130,0,3,1,1,false)
    #label.draw_text("BP",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) GIVEN",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,false)
    #label.draw_text("#{visit_data['bp'] rescue nil}",185,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome_date']}",655,130,0,2,1,1,false)
    label.draw_text("#{visit_data['next_appointment']}",577,190,0,2,1,1,false) if visit_data['next_appointment']
    starting_index = 25
    start_line = 160

    visit_data.each{|key,values|
      data = values.last rescue nil
      next if data.blank?
      bold = false
      #bold = true if key.include?("side_eff") and data !="None"
      #bold = true if key.include?("arv_given")
      starting_index = values.first.to_i
      starting_line = start_line
      starting_line = start_line + 30 if key.include?("2")
      starting_line = start_line + 60 if key.include?("3")
      starting_line = start_line + 90 if key.include?("4")
      starting_line = start_line + 120 if key.include?("5")
      starting_line = start_line + 150 if key.include?("6")
      starting_line = start_line + 180 if key.include?("7")
      starting_line = start_line + 210 if key.include?("8")
      starting_line = start_line + 240 if key.include?("9")
      next if starting_index == 0
      label.draw_text("#{data}",starting_index,starting_line,0,2,1,1,bold)
    } rescue []
    label.print(2)
    #end
  end

  def seen_by(patient,date = Date.today)
    provider = patient.encounters.find_by_date(date).collect{|e| next unless e.name == 'HIV CLINIC CONSULTATION' ; [e.name,e.creator]}.compact
    provider_username = "#{'Seen by: ' + User.find(provider[0].last).username}" unless provider.blank?
    if provider_username.blank?
      clinic_encounters = ["EPILEPSY CLINIC VISIT","DIABETES HYPERTENSION INITIAL VISIT","TREATMENT",'APPOINTMENT']
      encounter_type_ids = EncounterType.find(:all,:conditions =>["name IN (?)",clinic_encounters]).collect{| e | e.id }
      encounter = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type In (?)",
					patient.id,encounter_type_ids],:order => "encounter_datetime DESC")
      provider_username = "#{'Recorded by: ' + User.find(encounter.creator).username}" rescue nil
    end
    provider_username
  end

	def mastercard_visit_data(visit)
		return if visit.blank?
    data = {}

    data["bp"] = visit.bp rescue nil
    data["outcome"] = visit.outcome rescue nil
    data["outcome_date"] = "#{visit.date_of_outcome.to_date.strftime('%b %d %Y')}" if visit.date_of_outcome

    if visit.appointment_date
      data["next_appointment"] = "Next: #{visit.appointment_date.strftime('%b %d %Y')}"
    end

    count = 1
    (visit.s_eff.split("<br/>").compact.reject(&:blank?) || []).each do |side_eff|
      data["side_eff#{count}"] = "25",side_eff[0..5]
      count+=1
    end if visit.s_eff

    count = 1
    (visit.gave || []).each do | drug, pills |
      string = "#{drug} (#{pills})"
      if string.length > 26
        line = string[0..25]
        line2 = string[26..-1]
        data["arv_given#{count}"] = "255",line
        data["arv_given#{count+=1}"] = "255",line2
      else
        data["arv_given#{count}"] = "255",string
      end
      count+= 1
    end rescue []

    unless visit.cpt.blank?
      data["arv_given#{count}"] = "255","CPT (#{visit.cpt})" unless visit.cpt == 0
    end rescue []

    data
	end

  def current_vitals(patient, vital_sign, session_date = Date.today)
    concept = ConceptName.find_by_sql("select concept_id from concept_name where name = '#{vital_sign}' and voided = 0").first.concept_id
    Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{patient.id}'
                    AND DATE(obs_datetime) <= '#{session_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first rescue nil
	end

  def specific_vitals(patient, vital_sign, session_date = Date.today)
    concept = ConceptName.find_by_sql("select concept_id from concept_name where name = '#{vital_sign}' and voided = 0").first.concept_id
    Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{patient.id}'
                    AND DATE(obs_datetime) = '#{session_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first rescue nil
	end

  def current_encounter(patient, enc, concept, session_date = Date.today)
    concept = ConceptName.find_by_name(concept).concept_id

    encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
      :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
        session_date ,patient.id, EncounterType.find_by_name(enc).id]).encounter_id rescue nil
    Observation.find(:all, :order => "obs_datetime DESC,date_created DESC", :conditions => ["encounter_id = ? AND concept_id = ?", encounter, concept]) rescue nil
  end
  
  def specific_encounter_with_date(patient, enc, concept, session_date = Date.today)
    
    concept = ConceptName.find_by_name(concept).concept_id
    encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
      :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
        session_date ,patient.id, EncounterType.find_by_name(enc).id]).encounter_id rescue nil

        
    Observation.find(:all, :order => "obs_datetime DESC,date_created DESC", :conditions => ["encounter_id = ? AND concept_id = ? AND value_numeric IS NOT NULL", encounter, concept]) rescue nil
  end

  def specific_encounter(patient, enc, concept, session_date = Date.today)
    
    concept = ConceptName.find_by_name(concept).concept_id
    encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
      :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
        session_date ,patient.id, EncounterType.find_by_name(enc).id]).encounter_id rescue nil

        
    Observation.find(:all, :order => "obs_datetime DESC,date_created DESC", :conditions => ["encounter_id = ? AND concept_id = ?", encounter, concept]) rescue nil
  end

	def visits(patient_obj, encounter_date = nil)
    
    patient_visits = {}
    yes = ConceptName.find_by_name("YES")
    concept_names = ["APPOINTMENT DATE", "HEIGHT (CM)", 'WEIGHT (KG)',
			"BODY MASS INDEX, MEASURED", "RESPONSIBLE PERSON PRESENT",
			"PATIENT PRESENT FOR CONSULTATION", "TB STATUS",
			"AMOUNT DISPENSED", "ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT",
			"DRUG INDUCED", "AMOUNT OF DRUG BROUGHT TO CLINIC",
			"WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER",
			"CLINICAL NOTES CONSTRUCT","ASSESSMENT COMMENTS"]
    concept_ids = ConceptName.find(:all, :conditions => ["name in (?)", concept_names]).map(&:concept_id)

    if encounter_date.blank?
      observations = Observation.find(:all,
				:conditions =>["voided = 0 AND person_id = ? AND concept_id IN (?)",
					patient_obj.patient_id, concept_ids],
				:order =>"obs_datetime").map{|obs| obs if !obs.concept.nil?}
    else
      observations = Observation.find(:all,
        :conditions =>["voided = 0 AND person_id = ? AND Date(obs_datetime) = ? AND concept_id IN (?)",
          patient_obj.patient_id,encounter_date.to_date, concept_ids],
        :order =>"obs_datetime").map{|obs| obs if !obs.concept.nil?}
    end
		#raise observations.last.concept_id.to_s.to_yaml
		gave_hash = Hash.new(0)
		observations.map do |obs|
			drug = Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
			#if !drug.blank?
      #tb_medical = MedicationService.tb_medication(drug)
      #next if tb_medical == true
			#end
			encounter_name = obs.encounter.name rescue []
			next if encounter_name.blank?
			next if encounter_name.match(/REGISTRATION/i)
			next if encounter_name.match(/HIV STAGING/i)
			visit_date = obs.obs_datetime.to_date
			patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?


      patient_visits[visit_date].bp = calculate_bp(patient_obj, visit_date)
      patient_visits[visit_date].smoker = current_vitals(patient_obj,"current smoker", visit_date).to_s.match(/yes/i) rescue nil
      ! patient_visits[visit_date].smoker.blank? ? patient_visits[visit_date].smoker = "Y" : patient_visits[visit_date].smoker = "N"
     
      patient_visits[visit_date].alcohol = current_vitals(patient_obj,"Does the patient drink alcohol?", visit_date).to_s.match(/yes/i) rescue nil
      ! patient_visits[visit_date].alcohol.blank? ? patient_visits[visit_date].alcohol = "Y" : patient_visits[visit_date].alcohol = "N"

      patient_visits[visit_date].cva_risk = current_vitals(patient_obj, "assessment comments", visit_date).to_s.split(":")[1] rescue "Unknown"

      patient_visits[visit_date].acuity = "N/A"

      patient_visits[visit_date].fbs = specific_vitals(patient_obj,"fasting", visit_date).obs_group_id rescue []
      patient_visits[visit_date].fbs = Observation.find(:all, :conditions => ['obs_group_id = ?', patient_visits[visit_date].fbs]).first.value_numeric.to_i rescue "Not taken"

      patient_visits[visit_date].urine = specific_encounter_with_date(patient_obj, "LAB RESULTS","serum creatinine", visit_date).first.to_s.split(":")[1].to_i rescue "Not taken"

      program_id = Program.find_by_name('CHRONIC CARE PROGRAM').id
      
			concept_name = obs.concept.fullname
      
			if concept_name.upcase == 'APPOINTMENT DATE'
				patient_visits[visit_date].appointment_date = obs.value_datetime
			elsif concept_name.upcase == 'HEIGHT (CM)'
				patient_visits[visit_date].height = obs.answer_string
			elsif concept_name.upcase == 'WEIGHT (KG)'
				patient_visits[visit_date].weight = obs.answer_string
			elsif concept_name.upcase == 'BODY MASS INDEX, MEASURED'
				patient_visits[visit_date].bmi = obs.answer_string
			elsif concept_name == 'RESPONSIBLE PERSON PRESENT' or concept_name == 'PATIENT PRESENT FOR CONSULTATION'
				patient_visits[visit_date].visit_by = '' if patient_visits[visit_date].visit_by.blank?
				patient_visits[visit_date].visit_by+= "P" if obs.to_s.squish.match(/Patient present for consultation: Yes/i)
				patient_visits[visit_date].visit_by+= "G" if obs.to_s.squish.match(/Responsible person present: Yes/i)
        #elsif concept_name.upcase == 'TB STATUS'
        #	status = tb_status(patient_obj).upcase rescue nil
        #	patient_visits[visit_date].tb_status = status
        #	patient_visits[visit_date].tb_status = 'noSup' if status == 'TB NOT SUSPECTED'
        #	patient_visits[visit_date].tb_status = 'sup' if status == 'TB SUSPECTED'
        #	patient_visits[visit_date].tb_status = 'noRx' if status == 'CONFIRMED TB NOT ON TREATMENT'
        #	patient_visits[visit_date].tb_status = 'Rx' if status == 'CONFIRMED TB ON TREATMENT'
        #	patient_visits[visit_date].tb_status = 'Rx' if status == 'CURRENTLY IN TREATMENT'

			elsif concept_name.upcase == 'AMOUNT DISPENSED'

				drug = Drug.find(obs.value_drug) rescue nil
				#tb_medical = MedicationService.tb_medication(drug)
				#next if tb_medical == true
				next if drug.blank?
				drug_name = drug.concept.shortname rescue drug.name
				if drug_name.match(/Cotrimoxazole/i) || drug_name.match(/CPT/i)
					patient_visits[visit_date].cpt += obs.value_numeric unless patient_visits[visit_date].cpt.blank?
					patient_visits[visit_date].cpt = obs.value_numeric if patient_visits[visit_date].cpt.blank?
				else
					tb_medical = MedicationService.tb_medication(drug)
					patient_visits[visit_date].gave = [] if patient_visits[visit_date].gave.blank?
					patient_visits[visit_date].gave << [drug_name,obs.value_numeric]
					drugs_given_uniq = Hash.new(0)
					(patient_visits[visit_date].gave || {}).each do |drug_given_name,quantity_given|
						drugs_given_uniq[drug_given_name] += quantity_given
					end
					patient_visits[visit_date].gave = []
					(drugs_given_uniq || {}).each do |drug_given_name,quantity_given|
						patient_visits[visit_date].gave << [drug_given_name,quantity_given]
					end
				end
				#if !drug.blank?
				#	tb_medical = MedicationService.tb_medication(drug)
        #patient_visits[visit_date].ipt = [] if patient_visits[visit_date].ipt.blank?
        #patient_visits[visit_date].tb_status = "tb medical" if tb_medical == true
        #raise patient_visits[visit_date].tb_status.to_yaml
				#end

			elsif concept_name.upcase == 'ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT'
				patient_visits[visit_date].reg = 'Unknown' if obs.value_coded == ConceptName.find_by_name("Unknown antiretroviral drug").concept_id
				patient_visits[visit_date].reg =  Concept.find_by_concept_id(obs.value_coded).concept_names.typed("SHORT").first.name if !patient_visits[visit_date].reg

			elsif concept_name.upcase == 'DRUG INDUCED'
				symptoms = obs.to_s.split(':').map do | sy |
					sy.sub(concept_name,'').strip.capitalize
				end rescue []
				patient_visits[visit_date].s_eff = symptoms.join("<br/>") unless symptoms.blank?

			elsif concept_name.upcase == 'AMOUNT OF DRUG BROUGHT TO CLINIC'
				drug = Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
				#tb_medical = MedicationService.tb_medication(drug) unless drug.nil?
				#next if tb_medical == true
				next if drug.blank?
				drug_name = drug.concept.shortname rescue drug.name
				patient_visits[visit_date].pills = [] if patient_visits[visit_date].pills.blank?
				patient_visits[visit_date].pills << [drug_name,obs.value_numeric] rescue []

			elsif concept_name.upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER'
				drug = Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
				#tb_medical = MedicationService.tb_medication(drug) unless drug.nil?
				#next if tb_medical == true
				next if obs.value_numeric.blank?
				patient_visits[visit_date].adherence = [] if patient_visits[visit_date].adherence.blank?
				patient_visits[visit_date].adherence << [Drug.find(obs.order.drug_order.drug_inventory_id).name,(obs.value_numeric.to_s + '%')]
			elsif concept_name == 'CLINICAL NOTES CONSTRUCT' || concept_name == 'Clinical notes construct'
				patient_visits[visit_date].notes+= '<br/>' + obs.value_text unless patient_visits[visit_date].notes.blank?
				patient_visits[visit_date].notes = obs.value_text if patient_visits[visit_date].notes.blank?
			end
		end

    #patients currents/available states (patients outcome/s)
    program_id = Program.find_by_name('CHRONIC CARE PROGRAM').id
    
    if encounter_date.blank?
      patient_states = PatientState.find(:all,
				:joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
				:conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
					program_id,patient_obj.patient_id],:order => "patient_state_id ASC")
    else
      patient_states = PatientState.find(:all,
				:joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
				:conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND start_date = ? AND p.patient_id =?",
					program_id,encounter_date.to_date,patient_obj.patient_id],:order => "patient_state_id ASC")
    end
    
    #=begin
    patient_states.each do |state|
      visit_date = state.start_date.to_date rescue nil
      next if visit_date.blank?
      patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
      patient_visits[visit_date].outcome = state.program_workflow_state.concept.fullname rescue 'Alive'
      patient_visits[visit_date].date_of_outcome = state.start_date
    end
    #=end
    
    patient_visits.each do |visit_date,data|
      next if visit_date.blank?
      # patient_visits[visit_date].outcome = hiv_state(patient_obj,visit_date)
      #patient_visits[visit_date].date_of_outcome = visit_date

			status = tb_status(patient_obj, visit_date).upcase rescue nil
			patient_visits[visit_date].tb_status = status
      patient_visits[visit_date].tb_status = 'noSup' if status == 'UNKNOWN'
			patient_visits[visit_date].tb_status = 'noSup' if status == 'TB NOT SUSPECTED'
			patient_visits[visit_date].tb_status = 'sup' if status == 'TB SUSPECTED'
			patient_visits[visit_date].tb_status = 'noRx' if status == 'CONFIRMED TB NOT ON TREATMENT'
			patient_visits[visit_date].tb_status = 'Rx' if status == 'CONFIRMED TB ON TREATMENT'
			patient_visits[visit_date].tb_status = 'Rx' if status == 'CURRENTLY IN TREATMENT'
    end

    unless encounter_date.blank?
      outcome = patient_visits[encounter_date].outcome rescue nil
      if outcome.blank?
        state = PatientState.find(:first,
					:joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
					:conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
						program_id,patient_obj.patient_id],:order => "date_enrolled DESC,start_date DESC")

        patient_visits[encounter_date] = Mastercard.new() if patient_visits[encounter_date].blank?
        patient_visits[encounter_date].outcome = state.program_workflow_state.concept.fullname rescue 'Unknown state'
        patient_visits[encounter_date].date_of_outcome = state.start_date rescue nil
      end
    end

    patient_visits
  end

  def specific_patient_visit_date_label
		session_date = params[:session_date].to_date rescue Date.today
    @patient = Patient.find(params[:patient_id])
    print_string = patient_visit_label(@patient, session_date) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

	def tb_status(patient, visit_date = Date.today)
		state = Concept.find(Observation.find(:first,
        :order => "obs_datetime DESC,date_created DESC",
        :conditions => ["person_id = ? AND concept_id = ? AND value_coded IS NOT NULL AND obs_datetime <= ?",
          patient.id, ConceptName.find_by_name("TB STATUS").concept_id, visit_date]).value_coded).fullname rescue "UNKNOWN"
		#programs = patient.patient_programs.all rescue []

		#programs.each do |prog|
		#		tb_program = Program.find_by_name('TB PROGRAM').id
		#		patient_program_id = PatientProgram.find_by_sql("SELECT  patient_program_id FROM patient_program
		#										WHERE patient_id = #{patient.id}
		#										AND program_id = #{tb_program}
		#										AND voided = 0 LIMIT 1").first.patient_program_id  rescue state

		#		state = PatientState.find_by_sql("SELECT state  FROM patient_state
		#										WHERE patient_program_id = #{patient_program_id}
		#										AND voided = 0
		#										AND start_date <= '#{visit_date}'
		#										ORDER BY start_date DESC").last.state  rescue state
		#		state = ProgramWorkflowState.find_state(state).concept.fullname rescue state
		#end

		state

  end

end
