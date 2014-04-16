
class PatientsController < ApplicationController
  before_filter :find_patient

  def show
    @patient = Patient.find(params[:id] || params[:patient_id]) rescue nil

    if @patient.nil?
      redirect_to "/encounters/no_patient" and return
    end

    @retrospective = session[:datetime]
		@retrospective = Time.now if session[:datetime].blank?

    if params[:user_id].nil?
      redirect_to "/encounters/no_user" and return
    end

    @user = User.find(params[:user_id]) rescue nil
    
    redirect_to "/encounters/no_user" and return if @user.nil?

    session[:patient_id] = @patient.id
    session[:user_id] = @user.id
    session[:location_id] = params[:location_id]

    program_id = Program.find_by_name('CHRONIC CARE PROGRAM').id
    date = Date.today
    @current_state = PatientState.find_by_sql("SELECT p.patient_id, current_state_for_program(p.patient_id, #{program_id}, '#{date}') AS state, c.name as status FROM patient p
                      INNER JOIN  patient_program pp on pp.patient_id = p.patient_id
                      inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                      INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{program_id}, '#{date}')
                      INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                      WHERE DATE(ps.start_date) <= '#{date}'
                      AND p.patient_id = #{@patient.id}").first.status rescue ""


    @task = TaskFlow.new(params[:user_id], @patient.id)
		
    @links = {}

		@project = get_global_property_value("project.name") rescue "Unknown"
		current_user_activities = UserProperty.find_by_user_id_and_property(params[:user_id],
      "#{@project.downcase.gsub(/\s/, ".")}.activities").property_value.split(",").collect{|a| a.downcase} rescue []

     remote_ip = request.remote_ip
    host = request.host_with_port
    @task.tasks.each{|task|
			next if ! current_user_activities.include?(task.downcase)
      if task.upcase == "VITALS"
       @links[task.titleize] = "http://#{remote_ip}:3000/vitals?destination=http://#{host}/patients/processvitals/1?patient_id=#{@patient.id}&user_id=#{params[:user_id]}"
      else
        @links[task.titleize] = "/protocol_patients/#{task.gsub(/\s/, "_")}?patient_id=#{@patient.id}&user_id=#{params[:user_id]}"

      end
      @links[task.titleize] = "/patients/treatment_dashboard/#{@patient.id}?user_id=#{params[:user_id]}" if task.downcase == "treatment"
    }

    @demographics_url = get_global_property_value("patient.registration.url") rescue nil

    if !@demographics_url.nil?
      @demographics_url = @demographics_url + "/demographics/#{@patient.id}?user_id=#{@user.id}&ext=true"
    end
		@demographics_url = "http://" + @demographics_url if !@demographics_url.match(/http:/)
   
		if current_program == "ASTHMA PROGRAM"
			@task.asthma_next_task(host,remote_ip) rescue ""
		elsif current_program == "EPILEPSY PROGRAM"
			@task.epilepsy_next_task(host,remote_ip) rescue ""
    elsif current_program == "HYPERTENSION PROGRAM"
			@task.hypertension_next_task(host,remote_ip) rescue ""
		else
			@task.next_task(host,remote_ip) rescue ""
		end

		@disable = params[:disable] rescue ""

  end

  def dashboard_graph
    session_date = session[:datetime].to_date rescue Date.today
    @patient      = Patient.find(params[:id] || session[:patient_id] || params[:patient_id]) rescue nil

    patient_bean = PatientService.get_patient(@patient.person)

    #@encounters   = @patient.encounters.current.active.find(:all)
    @encounters   = @patient.encounters.find(:all, :conditions => ['DATE(encounter_datetime) = ?',session_date.to_date])
    excluded_encounters = ["Registration", "Diabetes history","Complications", #"Diabetes test",
      "General health", "Diabetes treatments", "Diabetes admissions","Hospital admissions",
      "Hypertension management", "Past diabetes medical history"]
    @encounter_names = @patient.encounters.active.map{|encounter| encounter.name}.uniq.delete_if{ |encounter| excluded_encounters.include? encounter.humanize } rescue []
    ignored_concept_id = Concept.find_by_name("NO").id;

    @observations = Observation.find(:all, :order => 'obs_datetime DESC',
      :limit => 50, :conditions => ["person_id= ? AND obs_datetime < ? AND value_coded != ?",
        @patient.patient_id, Time.now.to_date, ignored_concept_id])

    @observations.delete_if { |obs| obs.value_text.downcase == "no" rescue nil }

    # delete encounters that are not required for display on patient's summary
    @lab_results_ids = [Concept.find_by_name("Urea").id, Concept.find_by_name("Urine Protein").id, Concept.find_by_name("Creatinine").id]
    @encounters.map{ |encounter| (encounter.name == "DIABETES TEST" && encounter.observations.delete_if{|obs| !(@lab_results_ids.include? obs.concept.id)})} rescue nil
    @encounters.delete_if{|encounter|(encounter.observations == [])}

    @obs_datetimes = @observations.map { |each|each.obs_datetime.strftime("%d-%b-%Y")}.uniq

    @vitals = Encounter.find(:all, :order => 'encounter_datetime DESC',
      :limit => 50, :conditions => ["patient_id= ? AND encounter_datetime < ? ",
        @patient.patient_id, Time.now.to_date])

    @patient_treatements = DiabetesService.treatments(@patient)

    diabetes_id       = Concept.find_by_name("DIABETES MEDICATION").id

    @patient_diabetes_treatements     = []
    @patient_hypertension_treatements = []

    @patient_diabetes_treatements = DiabetesService.aggregate_treatments(@patient)

    selected_medical_history = ['DIABETES DIAGNOSIS DATE','SERIOUS CARDIAC PROBLEM','STROKE','HYPERTENSION','TUBERCULOSIS']
    @medical_history_ids = selected_medical_history.map { |medical_history| Concept.find_by_name(medical_history).id }
    @significant_medical_history = []
    @observations.each { |obs| @significant_medical_history << obs if @medical_history_ids.include? obs.concept_id}

    @arv_number = patient_bean.arv_number rescue nil
    @status     = PatientService.patient_hiv_status(@patient)
    #@status =Concept.find(Observation.find(:first,  :conditions => ["voided = 0 AND person_id= ? AND concept_id = ?",@patient.person.id, Concept.find_by_name('HIV STATUS').id], :order => 'obs_datetime DESC').value_coded).name.name rescue 'UNKNOWN'
    @hiv_test_date    = PatientService.hiv_test_date(@patient.id).strftime("%d/%b/%Y") rescue "UNKNOWN"
    @hiv_test_date = "Unkown" if @hiv_test_date.blank?
    @remote_art_info  = DiabetesService.remote_art_info(patient_bean.national_id) rescue nil


    @recents = DiabetesService.patient_recent_screen_complications(@patient.patient_id)

    # set the patient's medication period
    @patient_medication_period = DiabetesService.patient_diabetes_medication_duration(@patient.patient_id)
    render :layout => false
  end

  def processvitals
   
   
    encounter_type = EncounterType.find_by_name("VITALS").encounter_type_id
    uuid = ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid']
    date = session[:datetime] rescue Time.now
    person = Person.find(params[:patient_id]) rescue []
    patient = Patient.find(person.id)

     concept = ConceptName.find_by_sql("select concept_id from concept_name where name = 'height (cm)' and voided = 0").first.concept_id


    current  = Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{patient.id}'
                    AND DATE(obs_datetime) <= '#{date.to_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first.to_s.split(':')[1].squish rescue 0

    
      unless params["Height"].blank?
          current = params["Height"].to_i
      end
   


    concept = ConceptName.find_by_sql("select concept_id from concept_name where name = 'weight (kg)' and voided = 0").first.concept_id


    current  = Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{patient.id}'
                    AND DATE(obs_datetime) <= '#{date.to_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first.to_s.split(':')[1].squish rescue 0

    if current == 0
      unless params["Height"].blank?
          current = params["Height"].to_i
      end
    end

    sex =  patient.gender.downcase
    
	  if (sex == "female")
		  sex = "f"
    end
	  if (sex == "male")
		  sex = "m"
    end

    age = patient.age
    sex =  patient.gender.downcase

    user = User.find(params[:user_id]) rescue []
    location = session[:location_id]
    bmi = (weight/(current * current)*10000).round(1)
    unless person.blank?
      encounter = Encounter.create(
        :patient_id => person.id,
        :provider_id => user.id,
        :creator => user.id,
        :encounter_type => encounter_type,
        :location_id => location,
        :encounter_datetime => date,
        :date_created => Time.now,
        :uuid => uuid
      )
      (params|| []).each {|concept, value|
        if concept.match(/Systolic/i)
          concept = "SYstolic Blood Pressure"
        elsif concept.match(/Diastolic/i)
          concept = "Diastolic Blood Pressure"
        elsif concept.match(/Pulse/i)
          concept = "Pulse"
        elsif concept.match(/Height/i)
          concept = "Height (Cm)"
        elsif concept.match(/Oxygen/i)
          concept = "Blood Oxygen Saturation"
        elsif concept.match(/Respiratory/i)
          concept = "Peak Flow"

            if age < 18
              pefr = (((current - 100) * 5) + 100).to_i
            end
            if ((age >= 18) && (sex == "m"))
              current = current / 100
               pefr = ((((current * 5.48) + 1.58) - (age * 0.041)) * 60).to_i
            end

            if ((age >= 18) && (sex == "f"))
               current = current / 100
               pefr = ((((current * 3.72) + 2.24) - (age * 0.03)) * 60).to_i
            end

           estimate_id = ConceptName.find_by_name("peak flow predicted").concept_id rescue []

        unless estimate_id.blank?
          uuid = ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid']
          obs = Observation.create(
            :person_id => person.id,
            :concept_id => estimate_id,
            :location_id => encounter.location_id,
            :obs_datetime => encounter.encounter_datetime,
            :encounter_id => encounter.id,
            :value_numeric => pefr,
            :uuid => uuid,
            :date_created => Time.now,
            :creator => encounter.creator
          )
        end
         
        elsif concept.match(/Temperature/i)
          concept = "Temperature"
        end
        concept_id = ConceptName.find_by_name("#{concept}").concept_id rescue []

        unless concept_id.blank?
          uuid = ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid']
          obs = Observation.create(
            :person_id => person.id,
            :concept_id => concept_id,
            :location_id => encounter.location_id,
            :obs_datetime => encounter.encounter_datetime,
            :encounter_id => encounter.id,
            :value_numeric => value,
            :uuid => uuid,
            :date_created => Time.now,
            :creator => encounter.creator
          )
        end
      }
    end
    
    remote_ip = request.remote_ip
    host = request.host_with_port
    @task = TaskFlow.new(params[:user_id], params[:patient_id])
    if current_program == "ASTHMA PROGRAM"
			redirect_to @task.asthma_next_task(host,remote_ip).url
		elsif current_program == "EPILEPSY PROGRAM"
			redirect_to @task.epilepsy_next_task(host,remote_ip).url
    elsif current_program == "HYPERTENSION PROGRAM"
			redirect_to @task.hypertension_next_task(host,remote_ip).url
		else
			redirect_to @task.next_task(host,remote_ip).url
		end

  end

  def chart
    @bps = []
    if params[:type] == "bp"

      @bps << ["#{Date.today.to_s.gsub("-","/")}",678]
     
      render :partial => 'bp_chart'
    end
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
            (e.encounter.encounter_datetime.strftime("%H:%M") rescue []),
            (e.encounter.creator rescue "")
          ]
        },
        p.date_time.strftime("%d-%b-%Y")
      ]
    } if !@patient.nil?

    render :layout => false
  end

  def mastercard_modify
    if request.method == :get
      @patient_id = params[:id]
      @patient = Patient.find(params[:id])
      @edit_page = edit_mastercard_attribute(params[:field].to_s)

      if @edit_page == "guardian"
        @guardian = {}
        @patient.person.relationships.map{|r| @guardian[art_guardian(@patient)] = Person.find(r.person_b).id.to_s;'' }
        if  @guardian == {}
          redirect_to :controller => "relationships" , :action => "search",:patient_id => @patient_id
        end
      end
    else
      @patient_id = params[:patient_id]
      save_mastercard_attribute(params)
      if params[:source].to_s == "opd"
        redirect_to "/patients/opdcard/#{@patient_id}" and return
      elsif params[:from_demo] == "true"
        redirect_to :controller => "people" ,
					:action => "demographics",:id => @patient_id and return
      else
        redirect_to :action => "mastercard",:patient_id => @patient_id and return
      end
    end
  end

  def save_mastercard_attribute(params)
    patient = Patient.find(params[:patient_id])
    case params[:field]
    when 'arv_number'
      type = params['identifiers'][0][:identifier_type]
      #patient = Patient.find(params[:patient_id])
      patient_identifiers = PatientIdentifier.find(:all,
        :conditions => ["voided = 0 AND identifier_type = ? AND patient_id = ?",type.to_i,patient.id])

      patient_identifiers.map{|identifier|
        identifier.voided = 1
        identifier.void_reason = "given another number"
        identifier.date_voided  = Time.now()
        identifier.voided_by = current_user.id
        identifier.save
      }

      identifier = params['identifiers'][0][:identifier].strip
      if identifier.match(/(.*)[A-Z]/i).blank?
        params['identifiers'][0][:identifier] = "#{PatientIdentifier.site_prefix}-ARV-#{identifier}"
      end
      patient.patient_identifiers.create(params[:identifiers])
    when "name"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
      patient.person.names.first.update_attributes(names_params) if names_params
    when "age"
      birthday_params = params[:person]

      if !birthday_params.empty?
        if birthday_params["birth_year"] == "Unknown"
          PatientService.set_birthdate_by_age(patient.person, birthday_params["age_estimate"])
        else
          PatientService.set_birthdate(patient.person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
        end
        patient.person.birthdate_estimated = 1 if params["birthdate_estimated"] == 'true'
        patient.person.save
      end
    when "sex"
      gender ={"gender" => params[:gender].to_s}
      patient.person.update_attributes(gender) if !gender.empty?
    when "location"
      location = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(location) if location
    when "occupation"
      attribute = params[:person][:attributes]
      occupation_attribute = PersonAttributeType.find_by_name("Occupation")
      exists_person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", patient.person.id, occupation_attribute.person_attribute_type_id]) rescue nil
      if exists_person_attribute
        exists_person_attribute.update_attributes({'value' => attribute[:occupation].to_s})
      end
    when "guardian"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
      Person.find(params[:guardian_id].to_s).names.first.update_attributes(names_params) rescue '' if names_params
    when "address"
      address2 = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(address2) if address2
    when "ta"
      county_district = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(county_district) if county_district
		when "home_district"
      home_district = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(home_district) if home_district

    when "cell_phone_number"
      attribute_type = PersonAttributeType.find_by_name("Cell Phone Number").id
      person_attribute = patient.person.person_attributes.find_by_person_attribute_type_id(attribute_type)
      if person_attribute.blank?
        attribute = {'value' => params[:person]["cell_phone_number"],
					'person_attribute_type_id' => attribute_type,
					'person_id' => patient.id}
        PersonAttribute.create(attribute)
      else
        person_attribute.update_attributes({'value' => params[:person]["cell_phone_number"]})
      end
    when "office_phone_number"
      attribute_type = PersonAttributeType.find_by_name("Office Phone Number").id
      person_attribute = patient.person.person_attributes.find_by_person_attribute_type_id(attribute_type)
      if person_attribute.blank?
        attribute = {'value' => params[:person]["office_phone_number"],
					'person_attribute_type_id' => attribute_type,
					'person_id' => patient.id}
        PersonAttribute.create(attribute)
      else
        person_attribute.update_attributes({'value' => params[:person]["office_phone_number"]})
      end
    when "home_phone_number"
      attribute_type = PersonAttributeType.find_by_name("Home Phone Number").id
      person_attribute = patient.person.person_attributes.find_by_person_attribute_type_id(attribute_type)
      if person_attribute.blank?
        attribute = {'value' => params[:person]["home_phone_number"],
					'person_attribute_type_id' => attribute_type,
					'person_id' => patient.id}
        PersonAttribute.create(attribute)
      else
        person_attribute.update_attributes({'value' => params[:person]["home_phone_number"]})
      end
    end
  end

  def edit_mastercard_attribute(attribute_name)
    edit_page = attribute_name
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
            (e.encounter.encounter_datetime.strftime("%H:%M") rescue ""),
            (e.encounter.creator rescue "")
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
    @current_program = current_program

    render :layout => "application"

  end

  def mastercard_printable
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false
    #raise params.to_yaml
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
    #raise params.to_yaml
    

    @visits.keys.each do|day|
			@age_in_months_for_days[day] = PatientService.age_in_months(@patient.person, day.to_date)
    end rescue nil

    render :layout => false
  end

  def print_demographics
    #raise params[:user_id]
    print_and_redirect("/patients/patient_demographics_label/#{@patient.id}?user_id=#{params[:user_id]}", "/patients/show?id=#{@patient.id}&user_id=#{params[:user_id]}")
  end

  def patient_demographics_label
    print_string = demographics_label(params[:id])
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbl", :disposition => "inline")
  end


   def demographics_label(patient_id)
    patient = Patient.find(patient_id)
    #patient_bean = PatientService.get_patient(patient.person)
    #raise patient_bean.to_yaml
    demographics = mastercard_demographics(patient)
    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient.id])
=begin
    tb_within_last_two_yrs = "tb within last 2 yrs" unless demographics.tb_within_last_two_yrs.blank?
    eptb = "eptb" unless demographics.eptb.blank?
    pulmonary_tb = "Pulmonary tb" unless demographics.pulmonary_tb.blank?

    cd4_count_date = nil ; cd4_count = nil ; pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'CD4 COUNT DATETIME'
        cd4_count_date = obs.value_datetime.to_date
      when 'CD4 COUNT'
        cd4_count = obs.value_numeric
      when 'IS PATIENT PREGNANT?'
        pregnant = obs.to_s.split(':')[1] rescue nil
      end
    end rescue []
=end
    office_phone_number = PatientService.get_attribute(patient.person, 'Office phone number')
    home_phone_number = PatientService.get_attribute(patient.person, 'Home phone number')
    cell_phone_number = PatientService.get_attribute(patient.person, 'Cell phone number')

    phone_number = office_phone_number if not office_phone_number.downcase == "not available" and not office_phone_number.downcase == "unknown" rescue nil
    phone_number= home_phone_number if not home_phone_number.downcase == "not available" and not home_phone_number.downcase == "unknown" rescue nil
    phone_number = cell_phone_number if not cell_phone_number.downcase == "not available" and not cell_phone_number.downcase == "unknown" rescue nil

    initial_height = PatientService.get_patient_attribute_value(patient, "initial_height")
    initial_weight = PatientService.get_patient_attribute_value(patient, "initial_weight")

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
    label.draw_text("#{demographics.arv_number}",575,30,0,3,1,1,false)
    label.draw_text("PATIENT DETAILS",25,30,0,3,1,1,false)
    label.draw_text("Name:   #{demographics.name} (#{demographics.sex})",25,60,0,3,1,1,false)
    label.draw_text("DOB:    #{PatientService.birthdate_formatted(patient.person)}",25,90,0,3,1,1,false)
    label.draw_text("Phone: #{phone_number}",25,120,0,3,1,1,false)
    if demographics.address.length > 48
      label.draw_text("Addr:  #{demographics.address[0..47]}",25,150,0,3,1,1,false)
      label.draw_text("    :  #{demographics.address[48..-1]}",25,180,0,3,1,1,false)
      last_line = 180
    else
      label.draw_text("Addr:  #{demographics.address}",25,150,0,3,1,1,false)
      last_line = 150
    end

    if !demographics.guardian.nil?
      if last_line == 180 and demographics.guardian.length < 48
        label.draw_text("Guard: #{demographics.guardian}",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 180 and demographics.guardian.length > 48
        label.draw_text("Guard: #{demographics.guardian[0..47]}",25,210,0,3,1,1,false)
        label.draw_text("     : #{demographics.guardian[48..-1]}",25,240,0,3,1,1,false)
        last_line = 240
      elsif last_line == 150 and demographics.guardian.length > 48
        label.draw_text("Guard: #{demographics.guardian[0..47]}",25,180,0,3,1,1,false)
        label.draw_text("     : #{demographics.guardian[48..-1]}",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 150 and demographics.guardian.length < 48
        label.draw_text("Guard: #{demographics.guardian}",25,180,0,3,1,1,false)
        last_line = 180
      end
    else
      if last_line == 180
        label.draw_text("Guard: None",25,210,0,3,1,1,false)
        last_line = 210
      elsif last_line == 180
        label.draw_text("Guard: None}",25,210,0,3,1,1,false)
        last_line = 240
      elsif last_line == 150
        label.draw_text("Guard: None",25,180,0,3,1,1,false)
        last_line = 210
      elsif last_line == 150
        label.draw_text("Guard: None",25,180,0,3,1,1,false)
        last_line = 180
      end
    end

    label.draw_text("TI:    #{demographics.transfer_in ||= 'No'}",25,last_line+=30,0,3,1,1,false)
   # label.draw_text("FUP:   (#{demographics.agrees_to_followup})",25,last_line+=30,0,3,1,1,false)

=begin
    label2 = ZebraPrinter::StandardLabel.new
    #Vertical lines
    label2.draw_line(25,170,795,3)
    #label data
    label2.draw_text("STATUS AT ART INITIATION",25,30,0,3,1,1,false)
    label2.draw_text("(DSA:#{patient.date_started_art.strftime('%d-%b-%Y') rescue 'N/A'})",370,30,0,2,1,1,false)
    label2.draw_text("#{demographics.arv_number}",580,20,0,3,1,1,false)
    label2.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",25,300,0,1,1,1,false)

    label2.draw_text("RFS: #{demographics.reason_for_art_eligibility}",25,70,0,2,1,1,false)
    label2.draw_text("#{cd4_count} #{cd4_count_date}",25,110,0,2,1,1,false)
    label2.draw_text("1st + Test: #{demographics.hiv_test_date}",25,150,0,2,1,1,false)

    label2.draw_text("TB: #{tb_within_last_two_yrs} #{eptb} #{pulmonary_tb}",380,70,0,2,1,1,false)
    label2.draw_text("KS:#{demographics.ks rescue nil}",380,110,0,2,1,1,false)
    label2.draw_text("Preg:#{pregnant}",380,150,0,2,1,1,false)
    label2.draw_text("#{demographics.first_line_drugs.join(',')[0..32] rescue nil}",25,190,0,2,1,1,false)
    label2.draw_text("#{demographics.alt_first_line_drugs.join(',')[0..32] rescue nil}",25,230,0,2,1,1,false)
    label2.draw_text("#{demographics.second_line_drugs.join(',')[0..32] rescue nil}",25,270,0,2,1,1,false)

    label2.draw_text("HEIGHT: #{initial_height}",570,70,0,2,1,1,false)
    label2.draw_text("WEIGHT: #{initial_weight}",570,110,0,2,1,1,false)
    label2.draw_text("Init Age: #{PatientService.patient_age_at_initiation(patient, demographics.date_of_first_line_regimen) rescue nil}",570,150,0,2,1,1,false)

    line = 190
    extra_lines = []
    label2.draw_text("STAGE DEFINING CONDITIONS",450,190,0,3,1,1,false)

    (demographics.who_clinical_conditions.split(';') || []).each{|condition|
      line+=25
      if line <= 290
        label2.draw_text(condition[0..35],450,line,0,1,1,1,false)
      end
      extra_lines << condition[0..79] if line > 290
    } rescue []

    if line > 310 and !extra_lines.blank?
      line = 30
      label3 = ZebraPrinter::StandardLabel.new
      label3.draw_text("STAGE DEFINING CONDITIONS",25,line,0,3,1,1,false)
      label3.draw_text("#{PatientService.get_patient_identifier(patient, 'ARV Number')}",370,line,0,2,1,1,false)
      label3.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
      extra_lines.each{|condition|
        label3.draw_text(condition,25,line+=30,0,2,1,1,false)
      } rescue []
    end
=end
    #return "#{label.print(1)} #{label2.print(1)} #{label3.print(1)}" if !extra_lines.blank?
    return "#{label.print(1)}"
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

  def dashboard_print_national_id
   # raise params.to_yaml
   # unless params[:redirect].blank?
   #   redirect = "/#{params[:redirect]}/#{params[:id]}"
   # else
   #   redirect = "/patients/show/#{params[:id]}"
   # end
   # print_and_redirect("/patients/visit_label/?patient_id=#{params[:id]}&user_id=#{params[:user_id]}", "/patients/show/#{params[:id]}&user_id=#{params[:user_id]}")
    print_and_redirect("/patients/national_id_label?patient_id=#{params[:patient_id]}&user_id=#{params[:user_id]}", "/patients/show?patient_id=#{params[:patient_id]}&user_id=#{params[:user_id]}")
  end

  def patient_national_id_label(patient)
	  patient_bean = patient.person
    national_id = get_patient_identifier(patient, "National ID")
    
    sex =  patient_bean.gender.match(/F/i) ? "(F)" : "(M)"
    #raise sex.to_yaml
    address = patient.person.address.strip[0..24].humanize rescue ""
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,5,15,120,false,"#{national_id}")
    label.draw_multi_text("#{patient.name.titleize}")
    label.draw_multi_text("#{national_id} #{patient_bean.birthdate}#{sex}")
    label.draw_multi_text("#{address}")
    label.print(1)
  end

  def get_patient_identifier(patient, identifier_type)
    patient_identifier_type_id = PatientIdentifierType.find_by_name(identifier_type).patient_identifier_type_id rescue nil
    patient_identifier = PatientIdentifier.find(:first, :select => "identifier",
      :conditions  =>["patient_id = ? and identifier_type = ?", patient.id, patient_identifier_type_id],
      :order => "date_created DESC" ).identifier rescue nil
      return patient_identifier
  end


  def national_id_label
    print_string = patient_national_id_label(@patient)# rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def mastercard_demographics(patient_obj)
    
  	#patient_bean = PatientService.get_patient(patient_obj.person)
    visits = Mastercard.new()
    visits.zone = get_global_property_value("facility.zone.name") rescue "Unknown"
    visits.clinic = get_global_property_value("facility.name") rescue "Unknown"
    visits.district = get_global_property_value("facility.district") rescue "Unknown"
    visits.patient_id = patient_obj.id
    visits.arv_number = patient_obj.arv_number rescue ""
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

    visits.pork = current_vitals(patient_obj, "Food package provided").to_s.match(/Eats pork/i) rescue nil
    ! visits.pork.blank? ? visits.pork = "Y" : visits.pork = "N"

    visits.epilepsy = current_vitals(patient_obj, "Epilepsy").to_s.match(/yes/i) rescue nil
    ! visits.epilepsy.blank? ? visits.epilepsy = "Y" : visits.epilepsy = "N"

    visits.psychosis = current_vitals(patient_obj, "psychosis").to_s.match(/yes/i) rescue nil
    ! visits.psychosis.blank? ? visits.psychosis = "Y" : visits.psychosis = "N"

    visits.hyperactivity = current_vitals(patient_obj, "hyperactivity").to_s.match(/yes/i) rescue nil
    ! visits.hyperactivity.blank? ? visits.hyperactivity = "Y" : visits.hyperactivity = "N"

    visits.drug_related = current_encounter(patient_obj, "EPILEPSY CLINIC VISIT", "Cause of Seizure").to_s.match(/alcohol withdrawal/i) rescue nil
    ! visits.drug_related .blank? ? visits.drug_related  = "Y" : visits.drug_related  = "N"

    visits.known_seizure = current_vitals(patient_obj, "Seizures known epileptic").to_s.match(/yes/i) rescue nil
    ! visits.known_seizure.blank? ? visits.known_seizure = "Y" : visits.known_seizure = "N"

    visits.seizure_history = current_vitals(patient_obj, "Seizures").to_s.match(/yes/i) rescue nil
    ! visits.seizure_history.blank? ? visits.seizure_history = "Y" : visits.seizure_history = "N"

    visits.cysticercosis = current_vitals(patient_obj, "Cysticercosis").to_s.match(/yes/i) rescue nil
    ! visits.cysticercosis.blank? ? visits.cysticercosis = "Y" : visits.cysticercosis = "N"

    visits.cerebral_maralia = current_vitals(patient_obj, "Cysticercosis").to_s.match(/yes/i) rescue nil
    ! visits.cerebral_maralia.blank? ? visits.cerebral_maralia = "Y" : visits.cerebral_maralia = "N"

    visits.meningitis = current_vitals(patient_obj, "Meningitis").to_s.match(/yes/i) rescue nil
    ! visits.meningitis.blank? ? visits.meningitis = "Y" : visits.meningitis = "N"

    visits.burns = current_vitals(patient_obj, "Burns").to_s.match(/yes/i) rescue nil
    ! visits.burns.blank? ? visits.burns = "Y" : visits.burns = "N"


    visits.injuries = current_encounter(patient_obj, "EPILEPSY CLINIC VISIT", "Head injury").to_s.match(/yes/i) rescue nil
    # visits.injuries = current_vitals(patient_obj, "Head injury").to_s.match(/yes/i) rescue nil
    ! visits.injuries.blank? ? visits.injuries = "Y" : visits.injuries = "N"

    visits.head_trauma = current_encounter(patient_obj, "MEDICAL HISTORY", "Head injury").to_s.match(/yes/i) rescue nil
    # visits.injuries = current_vitals(patient_obj, "Head injury").to_s.match(/yes/i) rescue nil
    ! visits.head_trauma.blank? ? visits.head_trauma = "Y" : visits.head_trauma = "N"

    visits.atomic = current_vitals(patient_obj, "generalised").to_s.match(/Atomic/i) rescue nil
    ! visits.atomic.blank? ? visits.atomic = "Y" : visits.atomic = "N"

    visits.tonic = current_vitals(patient_obj, "generalised").to_s.match(/ Tonic/i) rescue nil
    ! visits.tonic.blank? ? visits.tonic = "Y" : visits.tonic = "N"

    visits.clonic = current_vitals(patient_obj, "generalised").to_s.match(/ Clonic/i) rescue nil
    ! visits.clonic.blank? ? visits.clonic = "Y" : visits.clonic = "N"

    visits.myclonic = current_vitals(patient_obj, "generalised").to_s.match(/ Myclonic/i) rescue nil
    ! visits.myclonic.blank? ? visits.myclonic = "Y" : visits.myclonic = "N"

    visits.absence = current_vitals(patient_obj, "generalised").to_s.match(/ Absence/i) rescue nil
    ! visits.absence.blank? ? visits.absence = "Y" : visits.absence = "N"

    visits.tonic_clonic = current_vitals(patient_obj, "generalised").to_s.match(/ Tonic Clonic/i) rescue nil
    ! visits.tonic_clonic.blank? ? visits.tonic_clonic = "Y" : visits.tonic_clonic = "N"

    visits.complex = current_vitals(patient_obj, "Focal seizure").to_s.match(/ Complex/i) rescue nil
    ! visits.complex.blank? ? visits.complex = "Y" : visits.complex = "N"

    visits.simplex = current_vitals(patient_obj, "Focal seizure").to_s.match(/ Simplex/i) rescue nil
    ! visits.simplex.blank? ? visits.simplex = "Y" : visits.simplex = "N"

    visits.unclassified = "N"
    if visits.atomic == "N" and visits.tonic == "N" and visits.clonic == "N" and visits.myclonic == "N" and visits.absence == "N" and visits.tonic_clonic == "N" and visits.complex == "N" and visits.simplex == "N"
      visits.unclassified = "Y"
    end

    visits.status_epileptus = current_vitals(patient_obj, "Confirm diagnosis of epilepsy").to_s.match(/yes/i) rescue nil
    ! visits.status_epileptus.blank? ? visits.status_epileptus = "Y" : visits.status_epileptus = "N"

    visits.mental_illness = current_vitals(patient_obj, "Mental Disorders").to_s.match(/yes/i) rescue nil
    ! visits.mental_illness.blank? ? visits.mental_illness = "Y" : visits.mental_illness = "N"

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
    systolic = Vitals.todays_vitals(patient, "Systolic blood pressure", visit_date).to_s.split(':')[1].squish #rescue 0
    diastolic = Vitals.todays_vitals(patient, "Diastolic blood pressure", visit_date).to_s.split(':')[1].squish #rescue 0
    
    return "#{systolic}/#{diastolic}"
  end

  def past_seizure(patient_id, visit_date, type = "")

    past_date = visit_date - 30.days
    concept = ConceptName.find_by_sql("select concept_id from concept_name where name = 'date of seizure' and voided = 0").first.concept_id
    obs = Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{patient_id}'
                    AND DATE(obs_datetime) < '#{visit_date}' AND DATE(obs_datetime) >= '#{past_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first.value_datetime.to_date rescue []
    
    return obs if type == "date"
    return "N" if obs.blank?
    return "Y" if obs.to_date >= past_date
    return "N"
  end

	def confirm
		session_date = session[:datetime] || Date.today

		@current_location = params[:location_id]
		@current_user = User.find(@user["user_id"])
		
		@found_person_id = params[:found_person_id] || session[:location_id]
		@relation = params[:relation] rescue []
		
    @person = Person.find(@found_person_id) rescue []


    @patient = Patient.find(@found_person_id) rescue []
    session[:patient_id] = @patient.id
    session[:user_id] = @current_user.id
    session[:location_id] = params[:location_id]
		@task = TaskFlow.new(params[:user_id], @person.id) rescue []
    concept_id = ConceptName.find_by_name("WEIGHT (KG)")
    @obs = Observation.find_by_sql("SELECT * FROM obs WHERE concept_id = '#{concept_id}'
                                    AND person_id = '#{@person.id}'")
     remote_ip = request.remote_ip
    host = request.host_with_port
		@next_task = @task.hypertension_next_task(host,remote_ip).encounter_type.gsub('_',' ') if current_program == "HYPERTENSION PROGRAM" rescue nil
		@next_task = @task.asthma_next_task(host,remote_ip).encounter_type.gsub('_',' ') if current_program == "ASTHMA PROGRAM" rescue nil
		@next_task = @task.epilepsy_next_task(host,remote_ip).encounter_type.gsub('_',' ') if current_program == "EPILEPSY PROGRAM" rescue nil
    @next_task = @task.next_task(host,remote_ip).encounter_type.gsub('_',' ') if current_program == "DIABETES PROGRAM" rescue nil


		@current_task = @task.hypertension_next_task(host,remote_ip) if current_program == "HYPERTENSION PROGRAM" rescue nil
    @current_task = @task.next_task(host,remote_ip) if current_program == "DIABETES PROGRAM" rescue nil
		@current_task = @task.asthma_next_task(host,remote_ip) if current_program == "ASTHMA PROGRAM" rescue nil
		@current_task = @task.epilepsy_next_task(host,remote_ip) if current_program == "EPILEPSY PROGRAM" rescue nil

		@arv_number = PatientService.get_patient_identifier(@person, 'ARV Number') rescue ""		
		@patient_bean = PatientService.get_patient(@person) rescue ""
		@location = Location.find(params[:location_id] || session[:location_id]).name rescue nil

		render :layout => 'menu'
	end

  def patient_bp
    patient = Patient.find(params[:patient_id])
    @bps = Observation.find(:all,
          :conditions => ["person_id = ? AND concept_id = ?", params[:patient_id], ConceptName.find_by_name("systolic blood pressure").concept_id], :order => "obs_datetime DESC", :limit => 5).collect{|o|
          [calculate_bp(patient,o.obs_datetime).split("/")[0].to_i, 
            o.obs_datetime.to_date.strftime('%Y/%m/%d'),
            calculate_bp(patient,o.obs_datetime).split("/")[1].to_i,
            (calculate_bp(patient,o.obs_datetime).split("/")[0].to_f / calculate_bp(patient,o.obs_datetime).split("/")[1].to_f).to_f.round(2)]}
    #raise @bps.to_yaml


    @bps = @bps.sort_by{|atr| atr[1]}.to_json
    render :partial => 'bp_chart' and return
  end

  def patient_overview
    @person = Person.find(params[:patient_id]) rescue []
    @conditions = []
    @conditions.push("<table id='overview'><th colspan=2 class='innerside'>Vist Overview</th>")
		if current_program == "EPILEPSY PROGRAM"
      @conditions.push("<tr><td>Visit Type</td><td>:  First Vist</td></tr>") if  is_first_epilepsy_clinic_visit(@person.id) == true
      @conditions.push("<tr><td>Visit Type</td><td>:  Follow up visit</td></tr>") if  is_first_epilepsy_clinic_visit(@person.id) != true
      @conditions.push("<tr><td>Expected Appointment date</td><td>: #{Vitals.get_patient_attribute_value(@person.patient, 'appointment date').to_date.strftime('%d/%m/%Y') rescue 'None'}</td></tr>") if  is_first_epilepsy_clinic_visit(@person.id) != true
		else
      @conditions.push("<tr><td>Visit Type</td><td>:  First Vist</td></tr>") if  is_first_hypertension_clinic_visit(@person.id) == true
      @conditions.push("<tr><td>Visit Type</td><td>:  Follow up visit</td></tr>") if  is_first_hypertension_clinic_visit(@person.id) != true

      if current_program == "HYPERTENSION PROGRAM" and is_first_hypertension_clinic_visit(@person.id) != true
        risk = Vitals.current_encounter(@person.patient, "assessment", "assessment comments") rescue "Previous Hypetension Assessment : Not Available"
      end
      @conditions.push("<tr><td>Expected Appointment date</td><td>: #{Vitals.get_patient_attribute_value(@person.patient, 'appointment date').to_date.strftime('%d/%m/%Y') rescue 'None'}") if  is_first_hypertension_clinic_visit(@person.id) != true
      @conditions.push("<tr><td colspan=2>#{risk} </td><tr>") if not risk.blank?
      @conditions.push("<tr><td>Asthma Expected Peak Flow Rate</td><td>  : #{Vitals.expectect_flow_rate(@person.patient).to_f.round} Litres/Minute</td></tr>") if  is_first_hypertension_clinic_visit(@person.id) != true
		end
    @conditions.push("</table>")
    render :partial => 'patient_overview'
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

		@project = get_global_property_value("project.name") rescue "Unknown"

    @advanced = get_global_property_value("prescription.types") rescue "Unknown"
    
    render :template => 'dashboards/treatment_dashboard', :layout => false
  end

  def treatment
		@user = User.find(params[:user_id]) rescue nil
		@patient = Patient.find(params[:patient_id] || params[:id]) rescue nil
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(start_date) = ?",
        type.id,@patient.id,session_date])

    #raise session_date.to_date.to_yaml
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
		@sbp = current_vitals(@patient, "systolic blood pressure").to_s.split(':')[1].squish rescue 0
		@dbp = current_vitals(@patient, "diastolic blood pressure").to_s.split(':')[1].squish rescue 0
    
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
            (e.encounter.encounter_datetime.strftime("%H:%M") rescue ""),
            (e.encounter.creator rescue "")
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
    program_id = Program.find_by_name('CHRONIC CARE PROGRAM').id

    appointments = Observation.find_by_sql("SELECT count(*) AS count FROM obs
      INNER JOIN encounter e USING(encounter_id) 
      INNER JOIN program_encounter pe ON e.patient_id = pe.patient_id
      WHERE concept_id = #{concept_id}
      AND pe.program_id = #{program_id}
      AND encounter_type = #{encounter_type.id} AND value_datetime >= '#{start_date}'
      AND value_datetime <= '#{end_date}' AND obs.voided = 0 GROUP BY value_datetime")
    count = appointments.first.count unless appointments.blank?
    count = '0' if count.blank?

    render :text => (count.to_i >= 0 ? {params[:date] => count}.to_json : 0)
  end

  def dashboard_visit_print
      print_and_redirect("/patients/visit_label/?patient_id=#{params[:id]}&user_id=#{params[:user_id]}", "/patients/show/#{params[:id]}&user_id=#{params[:user_id]}")
  end

  def prescription_print
    print_and_redirect("/patients/prescription_label/?patient_id=#{params[:id]}&user_id=#{params[:user_id]}", "/patients/treatment_dashboard/#{params[:id]}&user_id=#{params[:user_id]}")
  end

  def prescription_label
    		session_date = session[:datetime].to_date rescue Date.today
		@patient = Patient.find(params[:patient_id])
    print_string = prescription_print_label(@patient, session_date) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def prescription_print_label(patient, date = Date.today)
    visit = visits(patient, date, true)[date] rescue {}

		return if visit.blank?
    visit_data = mastercard_visit_data(visit)
    
    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    #label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    # label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient.name}(#{patient.gender})",25,60,0,3,1,1,false)
    #label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit.height + 'cm' if !visit.height.blank?}  #{visit.weight + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi if !visit.bmi.blank?}  #{'BP :' + visit_data['bp'] }",25,95,0,2,1,1,false) rescue ""
    #label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("TB",110,130,0,3,1,1,false)
    #label.draw_text("BP",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) PRESCRIBED",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,false)
    #label.draw_text("#{visit_data['bp'] rescue nil}",185,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome_date']}",655,130,0,2,1,1,false)
    label.draw_text("#{visit_data['next_appointment']}",577,190,0,2,1,1,false) if visit_data['next_appointment']
    starting_index = 25
    start_line = 160

     
    #starting_index = 30
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
    label.print(1)
  end

	def visit_label
		session_date = session[:datetime].to_date rescue Date.today
		@patient = Patient.find(params[:patient_id]) rescue Patient.find(params[:id])
		#raise @patient.to_yaml
    print_string = patient_visit_label(@patient, session_date) #rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

	def patient_visit_label(patient, date = Date.today)
    #result = Location.find(session[:location_id]).name.match(/outpatient/i)
		visit = visits(patient, date)[date] rescue {}

		return if visit.blank?
    visit_data = mastercard_visit_data(visit)
    #raise visit_data['bp'].to_yaml
    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    # label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient.name}(#{patient.gender})",25,60,0,3,1,1,false)
    #label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit.height + 'cm' if !visit.height.blank?}  #{visit.weight + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi if !visit.bmi.blank?}  #{'BP :' + visit_data['bp'] }",25,95,0,2,1,1,false) rescue ""
    #label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("Drug",60,130,0,3,1,1,false)
    #label.draw_text("BP",185,130,0,3,1,1,false)
    label.draw_text("DU",500,130,0,3,1,1,false)
    label.draw_text("FN",600,130,0,3,1,1,false)
    label.draw_text("Dose",677,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    starting_index = 25
    start_line = 160

    visit_data.each{|key,values|
      data = values.last.split(";") rescue nil
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
      label.draw_text("#{data[0]}",60,starting_line,0,2,1,1,bold)
      label.draw_text("#{data[1]}",600,starting_line,0,2,1,1,bold)
      label.draw_text("#{data[2]}",500,starting_line,0,2,1,1,bold)
      label.draw_text("#{data[3]}",677,starting_line,0,2,1,1,bold)
    } rescue []

    #starting_line = start_line + 30

   # label.draw_text("#{visit_data['outcome']}",80,starting_line,0,2,1,1,false)
    #label.draw_text("#{visit_data['outcome_date']}",255,starting_line,0,2,1,1,false)
    #label.draw_text("#{visit_data['next_appointment']}",577,starting_line,0,2,1,1,false) if visit_data['next_appointment']

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
      drug = drug.split(";")
      string = "#{drug[0]} (#{pills})"
      if string.length > 26
        line = string[0..25]
        line2 = string[26..-1]
        data["arv_given#{count}"] = "255",line
        data["arv_given#{count+=1}"] = "255","#{line2} ; #{drug[1]} ; #{drug[2]} ; #{drug[3]}"
      else
        data["arv_given#{count}"] = "255","#{string} ; #{drug[1]} ; #{drug[2]} ; #{drug[3]}"
      end
      count+= 1
    end #rescue []

    unless visit.cpt.blank?
      data["arv_given#{count}"] = "255","CPT (#{visit.cpt})" unless visit.cpt == 0
    end #rescue []

    data
	end

  def current_vitals(patient, vital_sign, session_date = Date.today)
    concept = ConceptName.find_by_name("#{vital_sign}").concept_id
    Observation.find_by_sql("SELECT * from obs where concept_id = #{concept} AND person_id = #{patient.id}
                    AND DATE(obs_datetime) <= '#{session_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first #rescue nil
	end

  def specific_vitals(patient, vital_sign, session_date = Date.today)
    concept = ConceptName.find_by_name("#{vital_sign}").concept_id
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

	def visits(patient_obj, encounter_date = nil, prescribed = false)
    patient_visits = {}
    yes = ConceptName.find_by_name("YES")
    concept_names = ["APPOINTMENT DATE", "HEIGHT (CM)", 'WEIGHT (KG)',
			"BODY MASS INDEX, MEASURED", "RESPONSIBLE PERSON PRESENT",
			"AMOUNT DISPENSED", "PRESCRIBE DRUGS",
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
		
		gave_hash = Hash.new(0)
		observations.map do |obs|
			drug = Drug.find(obs.order.drug_order.drug_inventory_id) rescue nil
			encounter_name = obs.encounter.name rescue []
			next if encounter_name.blank?
			visit_date = obs.obs_datetime.to_date
			patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?

      patient_visits[visit_date].last_seizures = past_seizure(patient_obj.id, visit_date)
      patient_visits[visit_date].last_seizure_date = past_seizure(patient_obj.id, visit_date, "date")

      patient_visits[visit_date].triggers = "Y"
      concept = ConceptName.find_by_sql("select concept_id from concept_name where name = 'Cause of Seizure' and voided = 0").first.concept_id
      triggers = Observation.find(:all, :order => "obs_datetime DESC,date_created DESC", :conditions => ["DATE(obs_datetime) = ? AND concept_id = ? AND person_id = ?", visit_date, concept, patient_obj.id]) rescue nil
      patient_visits[visit_date].triggers = "N" if triggers.blank?

      patient_visits[visit_date].last_seizure_date = visit_date if patient_visits[visit_date].last_seizure_date.blank?

      patient_visits[visit_date].bp = calculate_bp(patient_obj, visit_date)
      patient_visits[visit_date].smoker = current_vitals(patient_obj,"current smoker", visit_date).to_s.match(/yes/i) rescue nil
      ! patient_visits[visit_date].smoker.blank? ? patient_visits[visit_date].smoker = "Y" : patient_visits[visit_date].smoker = "N"
     
      patient_visits[visit_date].alcohol = current_vitals(patient_obj,"Does the patient drink alcohol?", visit_date).to_s.match(/yes/i) rescue nil
      ! patient_visits[visit_date].alcohol.blank? ? patient_visits[visit_date].alcohol = "Y" : patient_visits[visit_date].alcohol = "N"

      patient_visits[visit_date].number = current_vitals(patient_obj,"Number of seizure including current", visit_date).value_numeric.to_i rescue "Unknown"

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
				patient_visits[visit_date].bmi = obs.to_s.split(':')[1].squish rescue ""
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
      elsif concept_name.upcase == 'PRESCRIBE DRUGS'

       if prescribed == true
          patient_visits[visit_date].gave = []
          type = EncounterType.find_by_name('TREATMENT')
          prescriptions = Order.find(:all,
          :joins => "INNER JOIN encounter e USING (encounter_id)",
          :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(start_date) = ?",
            type.id,patient_obj.patient_id,visit_date.to_date])
            prescriptions.each{|drug_name|
              patient_visits[visit_date].gave  << [drug_name.drug_order.drug.name, drug_name.drug_order.amount_needed]
            }

          drugs_given_uniq = Hash.new(0)
					(patient_visits[visit_date].gave || {}).each do |drug_given_name,quantity_given|
						drugs_given_uniq[drug_given_name] += quantity_given
					end
					patient_visits[visit_date].gave = []
					(drugs_given_uniq || {}).each do |drug_given_name,quantity_given|
						patient_visits[visit_date].gave << [drug_given_name,quantity_given]
					end
        end

			elsif concept_name.upcase == 'AMOUNT DISPENSED'

				drug = Drug.find(obs.value_drug) rescue nil
				#tb_medical = MedicationService.tb_medication(drug)
				#next if tb_medical == true
				next if drug.blank?
        frequency = DrugOrder.find(obs.order_id).frequency
        dose = DrugOrder.find(obs.order_id).dose
        daily_dose = DrugOrder.find(obs.order_id).equivalent_daily_dose
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
						duration = (quantity_given / daily_dose).to_i
            patient_visits[visit_date].gave << ["#{drug_given_name} ; #{frequency} ; #{duration} ; #{dose}",quantity_given]
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

       #raise patient_visits[encounter_date].gave.to_yaml

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
    @patient = Patient.find(params[:patient_id]) rescue Patient.find(params[:id]) rescue []
    
    print_string = patient_visit_label(@patient, session_date) #rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
   
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
