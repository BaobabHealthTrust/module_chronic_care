
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
		#raise @task.to_yaml
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
    @patient = Patient.find(params[:id] || params[:patient_id]) rescue nil

    ProgramEncounter.current_date = (session[:datetime] || Time.now)
    
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

    # raise @programs.inspect

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

		@next_task = @task.next_task.encounter_type.gsub('_',' ') if current_program == "HYPERTENSION PROGRAM" rescue nil
		@next_task = @task.asthma_next_task.encounter_type.gsub('_',' ') if current_program == "ASTHMA PROGRAM" rescue nil
		@next_task = @task.epilepsy_next_task.encounter_type.gsub('_',' ') if current_program == "EPILEPSY PROGRAM" rescue nil

		@current_task = @task.next_task if current_program == "HYPERTENSION PROGRAM" rescue nil
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
		@sbp = Vitals.get_patient_attribute_value(@patient, "systolic blood pressure")
		@dbp = Vitals.get_patient_attribute_value(@patient, "diastolic blood pressure")

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
    result = Location.find(session[:location_id]).name.match(/outpatient/i)
		#visit = visits(patient, date)[date] rescue {}

		return if visit.blank?
    #visit_data = mastercard_visit_data(visit)

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
   # label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient.name}(#{patient.gender})",25,60,0,3,1,1,false)
    #label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    #label.draw_text("#{visit.height.to_s + 'cm' if !visit.height.blank?}  #{visit.weight.to_s + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s if !visit.bmi.blank?} #{'(PC:' + pill_count[0..24] + ')' unless pill_count.blank?}",25,95,0,2,1,1,false)
    #label.draw_text("SE",25,130,0,3,1,1,false)
    #label.draw_text("TB",110,130,0,3,1,1,false)
    label.draw_text("Adh",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) GIVEN",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    #label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,false)
    #label.draw_text("#{adherence_to_show(visit.adherence).gsub('%', '\\\\%') rescue nil}",185,160,0,2,1,1,false)
   # label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,false)
   # label.draw_text("#{visit_data['outcome_date']}",655,130,0,2,1,1,false)
    #label.draw_text("#{visit_data['next_appointment']}",577,190,0,2,1,1,false) if visit_data['next_appointment']
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

	def visits(patient_obj, encounter_date = nil)
    patient_visits = {}
    yes = ConceptName.find_by_name("YES")
    concept_names = ["APPOINTMENT DATE", "HEIGHT (CM)", 'WEIGHT (KG)',
			"BODY MASS INDEX, MEASURED", "RESPONSIBLE PERSON PRESENT",
			"PATIENT PRESENT FOR CONSULTATION", "TB STATUS",
			"AMOUNT DISPENSED", "ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT",
			"DRUG INDUCED", "AMOUNT OF DRUG BROUGHT TO CLINIC",
			"WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER",
			"CLINICAL NOTES CONSTRUCT"]
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
    program_id = Program.find_by_name('HIV PROGRAM').id
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
      patient_visits[visit_date].outcome = state.program_workflow_state.concept.fullname rescue 'Unknown state'
      patient_visits[visit_date].date_of_outcome = state.start_date
    end
#=end

    patient_visits.each do |visit_date,data|
      next if visit_date.blank?
     # patient_visits[visit_date].outcome = hiv_state(patient_obj,visit_date)
      #patient_visits[visit_date].date_of_outcome = visit_date

			status = tb_status(patient_obj, visit_date).upcase rescue nil
			patient_visits[visit_date].tb_status = status
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
