class CohortToolController < ApplicationController

  def select
    @cohort_quarters  = [""]
    @report_type      = params[:report_type]
    @header 	        = params[:report_type] rescue ""
    @page_destination = ("/" + params[:dashboard].gsub("_", "/")) rescue ""

    if @report_type == "in_arv_number_range"
      @arv_number_start = params[:arv_number_start]
      @arv_number_end   = params[:arv_number_end]
    end

    start_date  = PatientService.initial_encounter.encounter_datetime rescue Date.today

    end_date    = Date.today

    @cohort_quarters  += Report.generate_cohort_quarters(start_date, end_date)
  end

  def reports
    session[:list_of_patients] = nil
    if params[:report]
      case  params[:report_type]
      when "visits_by_day"
        redirect_to :action   => "visits_by_day",
          :name     => params[:report],
          :pat_name => "Visits by day",
          :quarter  => params[:report].gsub("_"," ")
        return

      when "non_eligible_patients_in_cohort"
        date = Report.generate_cohort_date_range(params[:report])

        redirect_to :action       => "non_eligible_patients_in_art",
          :controller   => "report",
          :start_date   => date.first.to_s,
          :end_date     => date.last.to_s,
          :id           => "start_reason_other",
          :report_type  => "non_eligible patients in: #{params[:report]}"
        return

      when "out_of_range_arv_number"
        redirect_to :action           => "out_of_range_arv_number",
          :arv_end_number   => params[:arv_end_number],
          :arv_start_number => params[:arv_start_number],
          :quarter          => params[:report].gsub("_"," "),
          :report_type      => params[:report_type]
        return

      when "data_consistency_check"
        redirect_to :action       => "data_consistency_check",
          :quarter      => params[:report],
          :report_type  => params[:report_type]
        return

      when "summary_of_records_that_were_updated"
        redirect_to :action   => "records_that_were_updated",
          :quarter  => params[:report].gsub("_"," ")
        return

      when "adherence_histogram_for_all_patients_in_the_quarter"
        redirect_to :action   => "adherence",
          :quarter  => params[:report].gsub("_"," ")
        return

      when "patients_with_adherence_greater_than_hundred"
        redirect_to :action  => "patients_with_adherence_greater_than_hundred",
          :quarter => params[:report].gsub("_"," ")
        return

      when "patients_with_multiple_start_reasons"
        redirect_to :action       => "patients_with_multiple_start_reasons",
          :quarter      => params[:report],
          :report_type  => params[:report_type]
        return

      when "dispensations_without_prescriptions"
        redirect_to :action       => "dispensations_without_prescriptions",
          :quarter      => params[:report],
          :report_type  => params[:report_type]
        return

      when "prescriptions_without_dispensations"
        redirect_to :action       => "prescriptions_without_dispensations",
          :quarter      => params[:report],
          :report_type  => params[:report_type]
        return

      when "drug_stock_report"
        start_date  = "#{params[:start_year]}-#{params[:start_month]}-#{params[:start_day]}"
        end_date    = "#{params[:end_year]}-#{params[:end_month]}-#{params[:end_day]}"

        if end_date.to_date < start_date.to_date
          redirect_to :controller   => "cohort_tool",
            :action       => "select",
            :report_type  =>"drug_stock_report" and return
        end rescue nil

        redirect_to :controller => "drug",
          :action     => "report",
          :start_date => start_date,
          :end_date   => end_date,
          :quarter    => params[:report].gsub("_"," ")
        return
      end
    end
  end

  def records_that_were_updated
    @quarter    = params[:quarter]

    date_range  = Report.generate_cohort_date_range(@quarter)
    @start_date = date_range.first
    @end_date   = date_range.last

    @encounters = records_that_were_corrected(@quarter)

    render :layout => false
  end

  def records_that_were_corrected(quarter)

    date        = Report.generate_cohort_date_range(quarter)
    start_date  = (date.first.to_s  + " 00:00:00")
    end_date    = (date.last.to_s   + " 23:59:59")

    voided_records = {}

    other_encounters = Encounter.find_by_sql("SELECT encounter.* FROM encounter
                        INNER JOIN obs ON encounter.encounter_id = obs.encounter_id
                        WHERE ((encounter.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'))
                        GROUP BY encounter.encounter_id
                        ORDER BY encounter.encounter_type, encounter.patient_id")

    drug_encounters = Encounter.find_by_sql("SELECT encounter.* as duration FROM encounter
                        INNER JOIN orders ON encounter.encounter_id = orders.encounter_id
                        WHERE ((encounter.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'))
                        ORDER BY encounter.encounter_type")

    voided_encounters = []
    other_encounters.delete_if { |encounter| voided_encounters << encounter if (encounter.voided == 1)}

    voided_encounters.map do |encounter|
      patient           = Patient.find(encounter.patient_id)
      patient_bean = PatientService.get_patient(patient.person)

      new_encounter  = other_encounters.reduce([])do |result, e|
        result << e if( e.encounter_datetime.strftime("%d-%m-%Y") == encounter.encounter_datetime.strftime("%d-%m-%Y")&&
            e.patient_id      == encounter.patient_id &&
            e.encounter_type  == encounter. encounter_type)
        result
      end

      new_encounter = new_encounter.last

      next if new_encounter.nil?

      voided_observations = voided_observations(encounter)
      changed_to    = changed_to(new_encounter)
      changed_from  = changed_from(voided_observations)

      if( voided_observations && !voided_observations.empty?)
        voided_records[encounter.id] = {
          "id"              => patient.patient_id,
          "arv_number"      => patient_bean.arv_number,
          "name"            => patient_bean.name,
          "national_id"     => patient_bean.national_id,
          "encounter_name"  => encounter.name,
          "voided_date"     => encounter.date_voided,
          "reason"          => encounter.void_reason,
          "change_from"     => changed_from,
          "change_to"       => changed_to
        }
      end
    end

    voided_treatments = []
    drug_encounters.delete_if { |encounter| voided_treatments << encounter if (encounter.voided == 1)}

    voided_treatments.each do |encounter|

      patient           = Patient.find(encounter.patient_id)
      patient_bean = PatientService.get_patient(patient.person)

      orders            = encounter.orders
      changed_from      = ''
      changed_to        = ''

      new_encounter  =  drug_encounters.reduce([])do |result, e|
        result << e if( e.encounter_datetime.strftime("%d-%m-%Y") == encounter.encounter_datetime.strftime("%d-%m-%Y")&&
            e.patient_id      == encounter.patient_id &&
            e.encounter_type  == encounter. encounter_type)
        result
      end

      new_encounter = new_encounter.last

      next if new_encounter.nil?
      changed_from  += "Treatment: #{voided_orders(new_encounter).to_s.gsub!(":", " =>")}</br>"
      changed_to    += "Treatment: #{encounter.to_s.gsub!(":", " =>") }</br>"

      if( orders && !orders.empty?)
        voided_records[encounter.id]= {
          "id"              => patient.patient_id,
          "arv_number"      => patient_bean.arv_number,
          "name"            => patient_bean.name,
          "national_id"     => patient_bean.national_id,
          "encounter_name"  => encounter.name,
          "voided_date"     => encounter.date_voided,
          "reason"          => encounter.void_reason,
          "change_from"     => changed_from,
          "change_to"       => changed_to
        }
      end

    end

    show_tabuler_format(voided_records)
  end

  def show_tabuler_format(records)

    patients = {}

    records.each do |key,value|

      sorted_values = sort(value)

      patients["#{key},#{value['id']}"] = sorted_values
    end

    patients
  end

  def sort(values)
    name              = ''
    patient_id        = ''
    arv_number        = ''
    national_id       = ''
    encounter_name    = ''
    voided_date       = ''
    reason            = ''
    obs_names         = ''
    changed_from_obs  = {}
    changed_to_obs    = {}
    changed_data      = {}

    values.each do |value|
      value_name =  value.first
      value_data =  value.last

      case value_name
      when "id"
        patient_id = value_data
      when "arv_number"
        arv_number = value_data
      when "name"
        name = value_data
      when "national_id"
        national_id = value_data
      when "encounter_name"
        encounter_name = value_data
      when "voided_date"
        voided_date = value_data
      when "reason"
        reason = value_data
      when "change_from"
        value_data.split("</br>").each do |obs|
          obs_name  = obs.split(':')[0].strip
          obs_value = obs.split(':')[1].strip rescue ''

          changed_from_obs[obs_name] = obs_value
        end unless value_data.blank?
      when "change_to"

        value_data.split("</br>").each do |obs|
          obs_name  = obs.split(':')[0].strip
          obs_value = obs.split(':')[1].strip rescue ''

          changed_to_obs[obs_name] = obs_value
        end unless value_data.blank?
      end
    end

    changed_from_obs.each do |a,b|
      changed_to_obs.each do |x,y|

        if (a == x)
          next if b == y
          changed_data[a] = "#{b} to #{y}"

          changed_from_obs.delete(a)
          changed_to_obs.delete(x)
        end
      end
    end

    changed_to_obs.each do |a,b|
      changed_from_obs.each do |x,y|
        if (a == x)
          next if b == y
          changed_data[a] = "#{b} to #{y}"

          changed_to_obs.delete(a)
          changed_from_obs.delete(x)
        end
      end
    end

    changed_data.each do |k,v|
      from  = v.split("to")[0].strip rescue ''
      to    = v.split("to")[1].strip rescue ''

      if obs_names.blank?
        obs_names = "#{k}||#{from}||#{to}||#{voided_date}||#{reason}"
      else
        obs_names += "</br>#{k}||#{from}||#{to}||#{voided_date}||#{reason}"
      end
    end

    results = {
      "id"              => patient_id,
      "arv_number"      => arv_number,
      "name"            => name,
      "national_id"     => national_id,
      "encounter_name"  => encounter_name,
      "voided_date"     => voided_date,
      "obs_name"        => obs_names,
      "reason"          => reason
    }

    results
  end

  def changed_from(observations)
    changed_obs = ''

    observations.collect do |obs|
      ["value_coded","value_datetime","value_modifier","value_numeric","value_text"].each do |value|
        case value
        when "value_coded"
          next if obs.value_coded.blank?
          changed_obs += "#{obs.to_s}</br>"
        when "value_datetime"
          next if obs.value_datetime.blank?
          changed_obs += "#{obs.to_s}</br>"
        when "value_numeric"
          next if obs.value_numeric.blank?
          changed_obs += "#{obs.to_s}</br>"
        when "value_text"
          next if obs.value_text.blank?
          changed_obs += "#{obs.to_s}</br>"
        when "value_modifier"
          next if obs.value_modifier.blank?
          changed_obs += "#{obs.to_s}</br>"
        end
      end
    end

    changed_obs.gsub("00:00:00 +0200","")[0..-6]
  end

  def changed_to(enc)
    encounter_type = enc.encounter_type

    encounter = Encounter.find(:first,
      :joins       => "INNER JOIN obs ON encounter.encounter_id=obs.encounter_id",
      :conditions  => ["encounter_type=? AND encounter.patient_id=? AND Date(encounter.encounter_datetime)=?",
        encounter_type,enc.patient_id, enc.encounter_datetime.to_date],
      :group       => "encounter.encounter_type",
      :order       => "encounter.encounter_datetime DESC")

    observations = encounter.observations rescue nil
    return if observations.blank?

    changed_obs = ''
    observations.collect do |obs|
      ["value_coded","value_datetime","value_modifier","value_numeric","value_text"].each do |value|
        case value
        when "value_coded"
          next if obs.value_coded.blank?
          changed_obs += "#{obs.to_s}</br>"
        when "value_datetime"
          next if obs.value_datetime.blank?
          changed_obs += "#{obs.to_s}</br>"
        when "value_numeric"
          next if obs.value_numeric.blank?
          changed_obs += "#{obs.to_s}</br>"
        when "value_text"
          next if obs.value_text.blank?
          changed_obs += "#{obs.to_s}</br>"
        when "value_modifier"
          next if obs.value_modifier.blank?
          changed_obs += "#{obs.to_s}</br>"
        end
      end
    end

    changed_obs.gsub("00:00:00 +0200","")[0..-6]
  end

  def visits_by_day
    @quarter    = params[:quarter]

    date_range          = Report.generate_cohort_date_range(@quarter)
    @start_date         = date_range.first
    @end_date           = date_range.last
    visits              = get_visits_by_day(@start_date.beginning_of_day, @end_date.end_of_day)
    @patients           = visiting_patients_by_day(visits)
    @visits_by_day      = visits_by_week(visits)
    @visits_by_week_day = visits_by_week_day(visits)

    render :layout => false
  end

  def visits_by_week(visits)

    visits_by_week = visits.inject({}) do |week, visit|

      day       = visit.encounter_datetime.strftime("%a")
      beginning = visit.encounter_datetime.beginning_of_week.to_date

      # add a new week
      week[beginning] = {day => []} if week[beginning].nil?

      #add a new visit to the week
      (week[beginning][day].nil?) ? week[beginning][day] = [visit] : week[beginning][day].push(visit)

      week
    end

    return visits_by_week
  end

  def visits_by_week_day(visits)
    week_day_visits = {}
    visits          = visits_by_week(visits)
    weeks           = visits.keys.sort
    week_days       = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    week_days.each_with_index do |day, index|
      weeks.map do  |week|
        visits_number = 0
        visit_date    = week.to_date.strftime("%d-%b-%Y")
        js_date       = week.to_time.to_i * 1000
        this_day      = visits[week][day]


        unless this_day.nil?
          visits_number = this_day.count
          visit_date    = this_day.first.encounter_datetime.to_date.strftime("%d-%b-%Y")
          js_date       = this_day.first.encounter_datetime.to_time.to_i * 1000
        else
          this_day      = (week.to_date + index.days)
          visit_date    = this_day.strftime("%d-%b-%Y")
          js_date       = this_day.to_time.to_i * 1000
        end

        (week_day_visits[day].nil?) ? week_day_visits[day] = [[js_date, visits_number, visit_date]] : week_day_visits[day].push([js_date, visits_number, visit_date])
      end
    end
    week_day_visits
  end

  def visiting_patients_by_day(visits)

    patients = visits.inject({}) do |patient, visit|

      visit_date = visit.encounter_datetime.strftime("%d-%b-%Y")

      patient_bean = PatientService.get_patient(visit.patient.person)

      # get a patient of a given visit
      new_patient   = { :patient_id   => (visit.patient.patient_id || ""),
        :arv_number   => (patient_bean.arv_number || ""),
        :name         => (patient_bean.name || ""),
        :national_id  => (patient_bean.national_id || ""),
        :gender       => (patient_bean.sex || ""),
        :age          => (patient_bean.age || ""),
        :birthdate    => (patient_bean.birth_date || ""),
        :phone_number => (PatientService.phone_numbers(visit.patient) || ""),
        :start_date   => (visit.patient.encounters.last.encounter_datetime.strftime("%d-%b-%Y") || "")
      }

      #add a patient to the day
      (patient[visit_date].nil?) ? patient[visit_date] = [new_patient] : patient[visit_date].push(new_patient)

      patient
    end

    patients
  end

  def get_visits_by_day(start_date,end_date)
    required_encounters = ["ART ADHERENCE", "ART_FOLLOWUP",   "ART_INITIAL",
      "ART VISIT",     "HIV RECEPTION",  "HIV STAGING",
      "PART_FOLLOWUP", "PART_INITIAL",   "VITALS"]

    required_encounters_ids = required_encounters.inject([]) do |encounters_ids, encounter_type|
      encounters_ids << EncounterType.find_by_name(encounter_type).id rescue nil
      encounters_ids
    end

    required_encounters_ids.sort!

    Encounter.find(:all,
      :joins      => ["INNER JOIN obs     ON obs.encounter_id    = encounter.encounter_id",
        "INNER JOIN patient ON patient.patient_id  = encounter.patient_id"],
      :conditions => ["obs.voided = 0 AND encounter_type IN (?) AND encounter_datetime >=? AND encounter_datetime <=?",required_encounters_ids,start_date,end_date],
      :group      => "encounter.patient_id,DATE(encounter_datetime)",
      :order      => "encounter.encounter_datetime ASC")
  end

  def prescriptions_without_dispensations
    include_url_params_for_back_button

    date_range  = Report.generate_cohort_date_range(params[:quarter])
    start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
    end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
    @report     = report_prescriptions_without_dispensations_data(start_date , end_date)

    render :layout => 'report'
  end

  def  dispensations_without_prescriptions
    include_url_params_for_back_button

    date_range  = Report.generate_cohort_date_range(params[:quarter])
    start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
    end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
    @report     = report_dispensations_without_prescriptions_data(start_date , end_date)

    render :layout => 'report'
  end

  def  patients_with_multiple_start_reasons
    include_url_params_for_back_button

    date_range  = Report.generate_cohort_date_range(params[:quarter])
    start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
    end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
    @report     = report_patients_with_multiple_start_reasons(start_date , end_date)

    render :layout => 'report'
  end

  def out_of_range_arv_number

    include_url_params_for_back_button

    date_range        = Report.generate_cohort_date_range(params[:quarter])
    start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
    end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")
    arv_number_range  = [params[:arv_start_number].to_i, params[:arv_end_number].to_i]

    @report = report_out_of_range_arv_numbers(arv_number_range, start_date, end_date)

    render :layout => 'report'
  end

  def data_consistency_check
    include_url_params_for_back_button
    date_range  = Report.generate_cohort_date_range(params[:quarter])
    start_date  = date_range.first.beginning_of_day.strftime("%Y-%m-%d %H:%M:%S")
    end_date    = date_range.last.end_of_day.strftime("%Y-%m-%d %H:%M:%S")

    @dead_patients_with_visits       = report_dead_with_visits(start_date, end_date)
    @males_allegedly_pregnant        = report_males_allegedly_pregnant(start_date, end_date)
    @move_from_second_line_to_first =  report_patients_who_moved_from_second_to_first_line_drugs(start_date, end_date)
    @patients_with_wrong_start_dates = report_with_drug_start_dates_less_than_program_enrollment_dates(start_date, end_date)
    session[:data_consistency_check] = { :dead_patients_with_visits => @dead_patients_with_visits,
      :males_allegedly_pregnant  => @males_allegedly_pregnant,
      :patients_with_wrong_start_dates => @patients_with_wrong_start_dates,
      :move_from_second_line_to_first =>  @move_from_second_line_to_first
    }
    @checks = [['Dead patients with Visits', @dead_patients_with_visits.length],
      ['Male patients with a pregnant observation', @males_allegedly_pregnant.length],
      ['Patients who moved from 2nd to 1st line drugs', @move_from_second_line_to_first.length],
      ['patients with start dates > first receive drug dates', @patients_with_wrong_start_dates.length]]
    render :layout => 'report'
  end

  def list
    @report = []
    include_url_params_for_back_button

    case params[:check_type]
    when 'Dead patients with Visits' then
      @report  =  session[:data_consistency_check][:dead_patients_with_visits]
    when 'Patients who moved from 2nd to 1st line drugs'then
      @report =  session[:data_consistency_check][:move_from_second_line_to_first]
    when 'Male patients with a pregnant observation' then
      @report =  session[:data_consistency_check][:males_allegedly_pregnant]
    when 'patients with start dates > first receive drug dates' then
      @report =  session[:data_consistency_check][:patients_with_wrong_start_dates]
    else

    end

    render :layout => 'report'
  end

  def include_url_params_for_back_button
    @report_quarter = params[:quarter]
    @report_type = params[:report_type]
  end

  def cohort
    @quarter = params[:quarter]
    start_date,end_date = Report.generate_cohort_date_range(@quarter)
    cohort = Cohort.new(start_date,end_date)
    @cohort = cohort.report
    render :layout => 'cohort'
  end

  def cohort_menu
  end

  def integrated_report
          @quarter = params[:quarter]
          @start_date, @end_date = Report.generate_cohort_date_range(@quarter)
          @user = User.find(params["user_id"]) rescue nil
          @logo = CoreService.get_global_property_value('logo').to_s
          @facility = Location.current_health_center.name rescue CoreService.get_global_property_value('facility.name') rescue ""
          @start_date, @end_date = Report.generate_cohort_date_range(@quarter)
          report = Reports::CohortDm.new(@start_date, @end_date)
          @specified_period = report.specified_period

          @total_registered = report.total_registered.length rescue 0
          ids = report.total_registered.map{|patient|patient.patient_id}.join(',') rescue ""
          ids = report.total_registered.map{|patient|patient.patient_id} if report.total_registered.length == 1
          @total_ever_registered = report.total_ever_registered.length rescue 0
          ids_ever = report.total_ever_registered.map{|patient|patient.patient_id}.join(',') rescue ""

          @registered_male = report.total_children_registered(ids, "male", 0, 1000)
          @registered_ever_male = report.total_children_registered(ids_ever, "male", 0, 1000, '1900-01-01')
          @registered_female = report.total_children_registered(ids, "female", 0, 1000)
          @registered_ever_female = report.total_children_registered(ids_ever, "female", 0, 1000, '1900-01-01')

          @registered_0_14 = report.total_children_registered(ids, nil, 0, 14)
          @registered_0_14_ever = report.total_children_registered(ids_ever, nil, 0, 14, '1900-01-01')

          @registered_14_44 = report.total_children_registered(ids, nil, 14, 44)
          @registered_14_44_ever = report.total_children_registered(ids_ever, nil, 14, 44, '1900-01-01')

          @registered_44_64 = report.total_children_registered(ids, nil, 44, 64)
          @registered_44_64_ever = report.total_children_registered(ids_ever, nil, 44, 64, '1900-01-01')

          @registered_64_1000 = report.total_children_registered(ids, nil, 64, 1000)
          @registered_64_1000_ever = report.total_children_registered(ids_ever, nil, 64, 1000, '1900-01-01')
          ht_male = report.disease_availabe(ids, "HT", "male").map{|patient|patient.patient_id}.uniq
          ht_female = report.disease_availabe(ids, "HT", "female").map{|patient|patient.patient_id}.uniq
          ever_ht_male = report.disease_availabe(ids_ever, "HT", "male").map{|patient|patient.patient_id}.uniq
          ever_ht_female = report.disease_availabe(ids_ever, "HT", "female").map{|patient|patient.patient_id}.uniq

          @ht = ht_male + ht_female
          @ht_ever = ever_ht_male + ever_ht_female

          dm_male = report.disease_availabe(ids, "DM", "male").map{|patient|patient.patient_id}.uniq - ht_male
          dm_female = report.disease_availabe(ids, "DM", "female").map{|patient|patient.patient_id}.uniq - ht_female
          ever_dm_male = report.disease_ever_availabe(ids_ever, "DM", "male").map{|patient|patient.patient_id}.uniq - ever_ht_male
          ever_dm_female = report.disease_ever_availabe(ids_ever, "DM", "female").map{|patient|patient.patient_id}.uniq - ever_ht_female

          @dm = dm_male + dm_female
          @dm_ever = ever_dm_male + ever_dm_female

          dmht_male = report.disease_availabe(ids, "dm ht", "male").map{|patient|patient.patient_id}.uniq # - report.disease_availabe(ids, "HT", "male").map{|patient|patient.patient_id}.uniq - report.disease_availabe(ids, "DM", "male").map{|patient|patient.patient_id}.uniq
          dmht_female = report.disease_availabe(ids, "dm ht", "female").map{|patient|patient.patient_id}.uniq #- report.disease_availabe(ids, "HT", "female").map{|patient|patient.patient_id}.uniq - report.disease_availabe(ids, "DM", "female").map{|patient|patient.patient_id}.uniq
          ever_dmht_male = report.disease_ever_availabe(ids_ever, "dm ht", "male").map{|patient|patient.patient_id}.uniq #- report.disease_ever_availabe(ids_ever, "HT", "male").map{|patient|patient.patient_id}.uniq - report.disease_ever_availabe(ids_ever, "DM", "male").map{|patient|patient.patient_id}.uniq
          ever_dmht_female = report.disease_ever_availabe(ids_ever, "dm ht", "female").map{|patient|patient.patient_id}.uniq #- report.disease_ever_availabe(ids_ever, "HT", "female").map{|patient|patient.patient_id}.uniq - report.disease_ever_availabe(ids_ever, "DM", "female").map{|patient|patient.patient_id}.uniq

          @dmht = dmht_male + dmht_female
          @dmht_ever = ever_dmht_male + ever_dmht_female


          asthma_male = report.disease_availabe(ids, "asthma", "male").map{|patient|patient.patient_id}.uniq
          asthma_female = report.disease_availabe(ids, "asthma", "female").map{|patient|patient.patient_id}.uniq
          ever_asthma_male = report.disease_ever_availabe(ids_ever, "asthma", "male").map{|patient|patient.patient_id}.uniq
          ever_asthma_female = report.disease_ever_availabe(ids_ever, "asthma", "female").map{|patient|patient.patient_id}.uniq

          @asthma = asthma_male + asthma_female
          @asthma_ever = ever_asthma_male + ever_asthma_female

         epilepsy_male = report.disease_availabe(ids, "epilepsy", "male").map{|patient|patient.patient_id}.uniq
         epilepsy_female = report.disease_availabe(ids, "epilepsy", "female").map{|patient|patient.patient_id}.uniq
         ever_epilepsy_male = report.disease_ever_availabe(ids_ever, "epilepsy", "male").map{|patient|patient.patient_id}.uniq
         ever_epilepsy_female = report.disease_ever_availabe(ids_ever, "epilepsy", "female").map{|patient|patient.patient_id}.uniq

         @epilepsy = epilepsy_male + epilepsy_female
         @epilepsy_ever = ever_epilepsy_male + ever_epilepsy_female

         overall_disease = @ht + @dm + @dmht + @asthma + @epilepsy
         overall_disease_ever = @ht_ever + @dm_ever + @dmht_ever + @asthma_ever + @epilepsy_ever
         #raise overall_disease.uniq.sort.length.to_yaml
         @other_ever = @total_ever_registered  -  overall_disease_ever.uniq.length
         @other = @total_registered - overall_disease.uniq.length

        @transfer_out_ever = report.transfer_out_ever(ids_ever)
        @stopped_treatment_ever = report.stopped_treatment_ever(ids_ever)
        @not_attend_ever = report.not_attending_ever(ids_ever)
        @lost_followup_ever = report.lost_followup_ever(ids_ever)

       @dead_ever = report.dead_ever(ids_ever)
       @attending = @total_ever_registered  - @not_attend_ever - @stopped_treatment_ever - @lost_followup_ever - @transfer_out_ever - @dead_ever

       bmi_female = report.bmi(ids, 'F')
       bmi_male = report.bmi(ids, 'M')
       @bmi = bmi_female + bmi_male
       bmi_ever_female = report.bmi_ever(ids_ever, 'F')
       bmi_ever_male = report.bmi_ever(ids_ever, 'M')
       @bmi_ever = bmi_ever_female + bmi_ever_male

      smoking_female = report.smoking(ids, 'F')
      smoking_male = report.smoking(ids, 'M')
      @smoking = smoking_female + smoking_male
      smoking_ever_female = report.smoking_ever(ids_ever, 'F')
      smoking_ever_male = report.smoking_ever(ids_ever, 'M')
      @smoking_ever = smoking_ever_female + smoking_ever_male

      alcohol_female = report.alcohol(ids, 'F')
      alcohol_male = report.alcohol(ids, 'M')
      @alcohol = alcohol_female + alcohol_male
      alcohol_ever_female = report.alcohol_ever(ids_ever, 'F')
      alcohol_ever_male = report.alcohol_ever(ids_ever, 'M')
      @alcohol_ever = alcohol_ever_male + alcohol_ever_female

     bp_female = report.decrease_in_bp(ids, 'F', 'low')
     bp_male = report.decrease_in_bp(ids, 'M', 'low')
     @low_bp = bp_female + bp_male
    bp_ever_female = report.decrease_in_bp(ids_ever, 'F', 'low')
    bp_ever_male = report.decrease_in_bp(ids_ever, 'M', 'low')
    @low_bp_ever = bp_ever_female + bp_ever_male

     bp_measured_female = report.decrease_in_bp(ids, 'F', 'measured')
     bp_measured_male = report.decrease_in_bp(ids, 'M', 'measured')
     @bp_measured = bp_measured_female + bp_measured_male
    bp_measured_ever_female = report.decrease_in_bp(ids_ever, 'F', 'measured')
    bp_measured_ever_male = report.decrease_in_bp(ids_ever, 'M', 'measured')
    @bp_measured_ever = bp_measured_ever_female + bp_measured_ever_male

    glucose_female = report.decrease_in_sugar(ids, 'F', "controlled")
    glucose_male = report.decrease_in_sugar(ids, 'M', "controlled")
    @glucose_controlled = glucose_female + glucose_male
    glucose_ever_female = report.decrease_in_sugar(ids_ever, 'F', "controlled")
    glucose_ever_male = report.decrease_in_sugar(ids_ever, 'M', "controlled")
    @glucose_ever_controlled = glucose_ever_female + glucose_ever_male


    glucose_female = report.decrease_in_sugar(ids, 'F', "measured")
    glucose_male = report.decrease_in_sugar(ids, 'M', "measured")
    @glucose_measured = glucose_female + glucose_male
    glucose_ever_female = report.decrease_in_sugar(ids_ever, 'F', "measured")
    glucose_ever_male = report.decrease_in_sugar(ids_ever, 'M', "measured")
    @glucose_ever_measured = glucose_ever_female + glucose_ever_male

    asthma = report.epilepsy_asthma(ids, "asthma").map{|patient|patient.patient_id}.uniq
    asthma_ever = report.epilepsy_asthma(ids_ever, "asthma").map{|patient|patient.patient_id}.uniq
    
    
    on_sabutamol_ever = report.patient_ids_on_drugs(ids_ever, 'Salbutamol')
    on_sabutamol = report.patient_ids_on_drugs(ids, 'Salbutamol') 
    on_beclomethasone = report.patient_ids_on_drugs(ids, 'beclomethasone')
    on_beclomethasone_ever = report.patient_ids_on_drugs(ids_ever, 'beclomethasone')
    
    @other_asthma = asthma - on_sabutamol.map{|patient|patient.patient_id}.uniq - on_beclomethasone.map{|patient|patient.patient_id}.uniq
    @other_asthma_ever = asthma_ever - on_sabutamol_ever.map{|patient|patient.patient_id}.uniq - on_beclomethasone_ever.map{|patient|patient.patient_id}.uniq

    epilepsy = report.epilepsy_asthma(ids, "epilepsy").map{|patient|patient.patient_id}.uniq
    epilepsy_ever = report.epilepsy_asthma(ids_ever, "epilepsy").map{|patient|patient.patient_id}.uniq
    
    hct_ever = report.patient_ids_on_drugs(ids_ever, 'hct')
    hct = report.patient_ids_on_drugs(ids, 'hct') 
    amlodipine = report.patient_ids_on_drugs(ids, 'Amlodipine')
    amlodipine_ever = report.patient_ids_on_drugs(ids_ever, 'Amlodipine')
    captopril = report.patient_ids_on_drugs(ids, 'captopril')
    captopril_ever = report.patient_ids_on_drugs(ids_ever, 'captopril')

    @no_asthma_ever = @total_ever_registered  -  asthma_ever.uniq.length
    @no_asthma = @total_registered - asthma.uniq.length

    @no_epilepsy_ever = @total_ever_registered  -  epilepsy_ever.uniq.length
    @no_epilepsy = @total_registered - epilepsy.uniq.length

    @stroke = report.stroke(ids) rescue 0
    @stroke_ever = report.stroke_ever(ids_ever) rescue 0


    controlled_male = report.controlled(ids, 'M')
    controlled_female = report.controlled(ids, 'F')
    @controlled = controlled_female + controlled_male
    controlled_ever_male = report.controlled(ids_ever, 'M')
    controlled_ever_female = report.controlled(ids_ever, 'F')
    @controlled_ever = controlled_ever_female + controlled_ever_male

    burns_male = report.burns_ever(ids, 'M')
    burns_female = report.burns_ever(ids, 'F')
    @burns = burns_female + burns_male
    burns_ever_male = report.burns_ever(ids_ever, 'M')
    burns_ever_female = report.burns_ever(ids_ever, 'F')
    @burns_ever = burns_ever_female + burns_ever_male

    mi_male = report.comp_mi_ever(ids, 'M')
    mi_female = report.comp_mi_ever(ids, 'F')
    @mi = mi_female + mi_male
    mi_ever_male = report.comp_mi_ever(ids_ever, 'M')
    mi_ever_female = report.comp_mi_ever(ids_ever, 'F')
    @mi_ever = mi_ever_male + mi_ever_female

    cardiovascular_male = report.cardiovascular_ever(ids, 'M')
    cardiovascular_female = report.cardiovascular_ever(ids, 'F')
    @cardiovascular = cardiovascular_male + cardiovascular_female
    cardiovascular_ever_male = report.cardiovascular_ever(ids_ever, 'M')
    cardiovascular_ever_female = report.cardiovascular_ever(ids_ever, 'F')
    @cardiovascular_ever = cardiovascular_ever_female + cardiovascular_ever_male

    blind_male = report.blind_ever(ids, 'M')
    blind_female = report.blind_ever(ids, 'F')
    @blind = blind_male + blind_female
    blind_ever_male = report.blind_ever(ids_ever, 'M')
    blind_ever_female = report.blind_ever(ids_ever, 'F')
    @blind_ever = blind_ever_male + blind_ever_female

    insulin_female = report.patient_on_drugs(ids, "F", 'Insulin')
    insulin_male = report.patient_on_drugs(ids, "M", 'Insulin')
    @insulin = insulin_female + insulin_female
    insulin_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Insulin')
    insulin_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Insulin')
    @insulin_ever = insulin_ever_female + insulin_ever_male

    glibe_female = report.patient_on_drugs(ids, "F", 'Glibenclamide')
    glibe_male = report.patient_on_drugs(ids, "M", 'Glibenclamide')
    @glibe = glibe_female + glibe_male
    glibe_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Glibenclamide')
    glibe_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Glibenclamide')
    @glibe_ever = glibe_ever_female + glibe_ever_male

    metformin_female = report.patient_on_drugs(ids, "F", 'Metformin')
    metformin_male = report.patient_on_drugs(ids, "M", 'Metformin')
    @metformin = metformin_female + metformin_male
    metformin_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Metformin')
    metformin_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Metformin')
    @metformin_ever = metformin_ever_female + metformin_ever_male

    amlodipine_female = report.patient_on_drugs(ids, "F", 'Amlodipine')
    amlodipine_male = report.patient_on_drugs(ids, "M", 'Amlodipine')
    @amlodipine = amlodipine_female + amlodipine_male
    amlodipine_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Amlodipine')
    amlodipine_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Amlodipine')
    @amlodipine_ever = amlodipine_ever_female + amlodipine_ever_male

    captopril_female = report.patient_on_drugs(ids, "F", 'captopril')
    captopril_male = report.patient_on_drugs(ids, "M", 'captopril')
    @captopril = captopril_female + captopril_male
    captopril_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'captopril')
    captopril_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'captopril')
    @captopril_ever = captopril_ever_female + captopril_ever_male

    hct_female = report.patient_on_drugs(ids, "F", 'hct')
    hct_male = report.patient_on_drugs(ids, "M", 'hct')
    @hct = hct_female + hct_male
    hct_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'hct')
    hct_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'hct')
    @hct_ever = hct_ever_female + hct_ever_male

    phenobarbitone_female = report.patient_on_drugs(ids, "F", 'phenobarbitone')
    phenobarbitone_male = report.patient_on_drugs(ids, "M", 'phenobarbitone')
    @phenobarbitone = phenobarbitone_female + phenobarbitone_male
    phenobarbitone_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'phenobarbitone')
    phenobarbitone_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'phenobarbitone')
    @phenobarbitone_ever = phenobarbitone_ever_female + phenobarbitone_ever_male

    phenytoin_female = report.patient_on_drugs(ids, "F", 'phenytoin')
    phenytoin_male = report.patient_on_drugs(ids, "M", 'phenytoin')
    @phenytoin = phenytoin_female + phenytoin_male
    phenytoin_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'phenytoin')
    phenytoin_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'phenytoin')
    @phenytoin_ever = phenytoin_ever_female + phenytoin_ever_male

    
    carbamazepine_female = report.patient_on_drugs(ids, "F", 'Carbamazepine')
    carbamazepine_male = report.patient_on_drugs(ids, "M", 'Carbamazepine')
    @carbamazepine = carbamazepine_female + carbamazepine_male
    carbamazepine_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Carbamazepine')
    carbamazepine_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'carbamazepine')
    @carbamazepine_ever = carbamazepine_ever_female + carbamazepine_ever_male

    salbutamol_female = report.patient_on_drugs(ids, "F", 'Salbutamol')
    salbutamol_male = report.patient_on_drugs(ids, "M", 'Salbutamol')
    @salbutamol = salbutamol_female + salbutamol_male
    salbutamol_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Salbutamol')
    salbutamol_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Salbutamol')
    @salbutamol_ever = salbutamol_ever_female + salbutamol_ever_male

    beclomethasone_female = report.patient_on_drugs(ids, "F", 'beclomethasone')
    beclomethasone_male = report.patient_on_drugs(ids, "M", 'beclomethasone')
    @beclomethasone = beclomethasone_female + beclomethasone_male
    beclomethasone_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'beclomethasone')
    beclomethasone_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'beclomethasone')
    @beclomethasone_ever = beclomethasone_ever_female + beclomethasone_ever_male

  end

  def voided_observations(encounter)
          voided_obs = Observation.find_by_sql("SELECT * FROM obs WHERE obs.encounter_id = #{encounter.encounter_id} AND obs.voided = 1")
          (!voided_obs.empty?) ? voided_obs : nil
  end

  def voided_orders(new_encounter)
          voided_orders = Order.find_by_sql("SELECT * FROM orders WHERE orders.encounter_id = #{new_encounter.encounter_id} AND orders.voided = 1")
          (!voided_orders.empty?) ? voided_orders : nil
  end

  def dm_cohort_report_options
        render :layout => false
  end

  def dm_cohort
    @quarter = params[:quarter]
    @start_date, @end_date = Report.generate_cohort_date_range(@quarter)
    @user = User.find(params["user_id"]) rescue nil
    @logo = CoreService.get_global_property_value('logo').to_s
    #cohort = Cohort.new(start_date,end_date)
    #@cohort = cohort.report
    #@survival_analysis = SurvivalAnalysis.report(cohort)

    #@start_date = params[:start_date] rescue nil
    #@end_date = params[:end_date] rescue nil
    
    report = Reports::CohortDm.new(@start_date, @end_date)
    @facility = Location.current_health_center.name rescue ''

    @specified_period = report.specified_period
    
    if params[:type] == "ccc"
              @total_registered = report.total_registered.length rescue 0
              ids = report.total_registered.map{|patient|patient.patient_id}.join(',') rescue ""
              ids = report.total_registered.map{|patient|patient.patient_id} if report.total_registered.length == 1
              @total_ever_registered = report.total_ever_registered.length rescue 0
              ids_ever = report.total_ever_registered.map{|patient|patient.patient_id}.join(',') rescue ""
    else
            @total_registered = report.total_registered("DIABETES HYPERTENSION INITIAL VISIT").length rescue 0
            ids = report.total_registered("DIABETES HYPERTENSION INITIAL VISIT").map{|patient|patient.patient_id.to_s}.join(',') rescue ""
            @total_ever_registered = report.total_ever_registered("DIABETES HYPERTENSION INITIAL VISIT").length rescue 0
            ids_ever = report.total_ever_registered("DIABETES HYPERTENSION INITIAL VISIT").map{|patient|patient.patient_id.to_s}.join(',') rescue ""
    end
    report.set_variable(ids_ever)
 if params[:type] != "ccc"
    @mi = report.mi(ids) rescue 0
    @kidney_failure = report.kidney_failure(ids) rescue 0
    @heart_failure = report.heart_failure(ids) rescue 0
    @stroke = report.stroke(ids) rescue 0
    @stroke_ever = report.stroke_ever(ids_ever) rescue 0
    @ulcers = report.ulcers(ids) rescue 0
    @ulcers_ever = report.ulcers_ever(ids_ever) rescue 0
    @impotence = report.impotence(ids) rescue 0
    @impotence_ever = report.impotence_ever(ids_ever) rescue 0
    @tia = report.tia(ids) rescue 0
    @tia_ever = report.tia_ever(ids_ever) rescue 0
    @mi_ever = report.mi_ever(ids_ever) rescue 0
    @kidney_failure_ever = report.kidney_failure_ever(ids_ever) rescue 0
    @heart_failure_ever = report.heart_failure_ever(ids_ever) rescue 0

    @oral_treatments_ever = report.oral_treatments_ever rescue 0
    @oral_treatments = report.oral_treatments #rescue 0
    @insulin_ever = report.insulin_ever rescue 0
    @insulin = report.insulin rescue 0
    @oral_and_insulin_ever = report.oral_and_insulin_ever rescue 0
    @oral_and_insulin = report.oral_and_insulin rescue 0
    @metformin_ever = report.metformin_ever rescue 0
    @metformin = report.metformin rescue 0
    @glibenclamide = report.glibenclamide rescue 0
    @glibenclamide_ever = report.glibenclamide_ever rescue 0
    @lente_insulin_ever = report.lente_insulin_ever rescue 0

    @lente_insulin = report.lente_insulin rescue 0

    @soluble_insulin_ever = report.soluble_insulin_ever rescue 0

    @soluble_insulin = report.soluble_insulin rescue 0

    @urine_protein_ever = report.urine_protein_ever rescue 0

    @urine_protein = report.urine_protein rescue 0

    @creatinine_ever = report.creatinine_ever rescue 0

    @creatinine = report.creatinine rescue 0


    @nephropathy_ever = @urine_protein_ever + @creatinine_ever

    @nephropathy = @urine_protein + @creatinine


    @numbness_symptoms_ever = report.numbness_symptoms_ever(ids_ever) rescue 0

    @numbness_symptoms = report.numbness_symptoms(ids) rescue 0


    @neuropathy_ever = @numbness_symptoms_ever

    @neuropathy = @numbness_symptoms

    @cataracts_ever = report.cataracts_ever rescue 0

    @cataracts = report.cataracts rescue 0

    @macrovascular_ever = report.macrovascular_ever rescue 0

    @macrovascular = report.macrovascular rescue 0

    @no_complications_ever = report.no_complications_ever(ids_ever) rescue 0

    @no_complications = report.no_complications(ids) rescue 0

    @amputation_ever = report.amputation_ever(ids_ever) rescue 0

    @amputation = report.amputation(ids) rescue 0

    @current_foot_ulceration_ever = report.current_foot_ulceration_ever(ids_ever) rescue 0

    @current_foot_ulceration = report.current_foot_ulceration(ids) rescue 0
    @amputations_or_ulcers_ever = @amputation_ever + @current_foot_ulceration_ever
    @amputations_or_ulcers = @amputation + @current_foot_ulceration
    @tb_known_ever = report.tb_known_ever(ids_ever) #rescue 0
    @tb_known = report.tb_known(ids) #rescue 0
    @tb_after_diabetes_ever = report.tb_after_diabetes_ever(ids_ever) rescue 0
    @tb_after_diabetes = report.tb_after_diabetes(ids) rescue 0
    @tb_before_diabetes_ever = report.tb_before_diabetes_ever(ids_ever) rescue 0
    @tb_before_diabetes = report.tb_before_diabetes(ids) rescue 0
    @tb_unknown_ever = report.tb_unkown_ever(ids_ever) rescue 0
    @tb_unknown = report.tb_unkown(ids) rescue 0
    @no_tb_ever = report.no_tb_ever(ids_ever) rescue 0
    @no_tb = report.no_tb(ids) rescue 0
    @tb_ever = report.tb_ever(ids_ever) rescue 0
    @tb = report.tb(ids) rescue 0
    @reactive_not_on_art_ever = report.reactive_not_on_art_ever(ids_ever) rescue 0
    @reactive_not_on_art = report.reactive_not_on_art(ids) rescue 0
    @reactive_on_art_ever = report.reactive_on_art_ever(ids_ever) rescue 0
    @reactive_on_art = report.reactive_on_art(ids) rescue 0
    @non_reactive_ever = report.non_reactive_ever(ids_ever) rescue 0
    @non_reactive = report.non_reactive(ids) rescue 0
    @unknown_ever = (@total_ever_registered.to_i - @non_reactive_ever.to_i -
        @reactive_on_art_ever.to_i - @reactive_not_on_art_ever.to_i)

    @unknown = (@total_registered.to_i - @non_reactive.to_i -
        @reactive_on_art.to_i - @reactive_not_on_art.to_i)

   end


    if params[:type] == "ccc"
    #Filter only htn dn asthma patients
    #raise ids.length.to_yaml
   # raise ids.to_yaml


      @total_adults_registered_male = report.total_children_registered(ids, "male", 14, 54)# rescue 0
    @total_adults_registered_female = report.total_children_registered(ids, "female", 14, 54)# rescue 0

    @older_persons_registered_male = report.total_children_registered(ids, "male", 54, 1000)
    @older_persons_registered_female = report.total_children_registered(ids, "female", 54, 1000)

    @older_persons_ever_registered_male = report.total_children_registered(ids_ever, "male", 54, 1000, '1900-01-01')
    @older_persons_ever_registered_female = report.total_children_registered(ids_ever, "female", 54, 1000, '1900-01-01')

    @total_adults_ever_registered_male = report.total_children_registered(ids_ever, "male", 14, 54, '1900-01-01')# rescue 0
    @total_adults_ever_registered_female = report.total_children_registered(ids_ever, "female", 14, 54, '1900-01-01')# rescue 0

    @total_children_registered_male = report.total_children_registered(ids, "male", 0, 14) #rescue 0
    @total_children_registered_female = report.total_children_registered(ids, "female", 0, 14)# rescue 0

    @total_children_ever_registered_male = report.total_children_registered(ids_ever, "male", 0, 14, '1900-01-01')
    @total_children_ever_registered_female = report.total_children_registered(ids_ever, "female", 0, 14, '1900-01-01')
    
    @disease_availabe_dm_male = report.disease_availabe(ids, "DM", "male").map{|patient|patient.patient_id}.uniq - report.disease_availabe(ids, "HT", "male").map{|patient|patient.patient_id}.uniq
    @disease_availabe_dm_female = report.disease_availabe(ids, "DM", "female").map{|patient|patient.patient_id}.uniq - report.disease_availabe(ids, "HT", "female").map{|patient|patient.patient_id}.uniq
    @disease_ever_availabe_dm_male = report.disease_ever_availabe(ids_ever, "DM", "male").map{|patient|patient.patient_id}.uniq - report.disease_ever_availabe(ids_ever, "HT", "male").map{|patient|patient.patient_id}.uniq
    @disease_ever_availabe_dm_female = report.disease_ever_availabe(ids_ever, "DM", "female").map{|patient|patient.patient_id}.uniq - report.disease_ever_availabe(ids_ever, "HT", "male").map{|patient|patient.patient_id}.uniq

    
    @disease_availabe_ht_male = report.disease_availabe(ids, "HT", "male").map{|patient|patient.patient_id}.uniq - report.disease_availabe(ids, "DM", "male").map{|patient|patient.patient_id}.uniq
    @disease_availabe_ht_female = report.disease_availabe(ids, "HT", "female").map{|patient|patient.patient_id}.uniq - report.disease_availabe(ids, "DM", "female").map{|patient|patient.patient_id}.uniq

    @disease_ever_availabe_ht_male = report.disease_ever_availabe(ids_ever, "HT", "male").map{|patient|patient.patient_id}.uniq - report.disease_ever_availabe(ids_ever, "DM", "male").map{|patient|patient.patient_id}.uniq
    @disease_ever_availabe_ht_female = report.disease_ever_availabe(ids_ever, "HT", "female").map{|patient|patient.patient_id}.uniq - report.disease_ever_availabe(ids_ever, "DM", "female").map{|patient|patient.patient_id}.uniq

    @disease_availabe_asthma_male = report.disease_availabe(ids, "asthma", "male").map{|patient|patient.patient_id}.uniq
    @disease_availabe_asthma_female = report.disease_availabe(ids, "asthma", "female").map{|patient|patient.patient_id}.uniq
    @disease_ever_availabe_asthma_male = report.disease_ever_availabe(ids_ever, "asthma", "male").map{|patient|patient.patient_id}.uniq
    @disease_ever_availabe_asthma_female = report.disease_ever_availabe(ids_ever, "asthma", "female").map{|patient|patient.patient_id}.uniq

    @disease_availabe_epilepsy_male = report.disease_availabe(ids, "epilepsy", "male").map{|patient|patient.patient_id}.uniq
    @disease_availabe_epilepsy_female = report.disease_availabe(ids, "epilepsy", "female").map{|patient|patient.patient_id}.uniq
    @disease_ever_availabe_epilepsy_male = report.disease_ever_availabe(ids_ever, "epilepsy", "male").map{|patient|patient.patient_id}.uniq
    @disease_ever_availabe_epilepsy_female = report.disease_ever_availabe(ids_ever, "epilepsy", "female").map{|patient|patient.patient_id}.uniq

    @disease_availabe_dmht_male = report.disease_availabe(ids, "dm ht", "male").map{|patient|patient.patient_id}.uniq # - report.disease_availabe(ids, "HT", "male").map{|patient|patient.patient_id}.uniq - report.disease_availabe(ids, "DM", "male").map{|patient|patient.patient_id}.uniq
    @disease_availabe_dmht_female = report.disease_availabe(ids, "dm ht", "female").map{|patient|patient.patient_id}.uniq #- report.disease_availabe(ids, "HT", "female").map{|patient|patient.patient_id}.uniq - report.disease_availabe(ids, "DM", "female").map{|patient|patient.patient_id}.uniq
    @disease_ever_availabe_dmht_male = report.disease_ever_availabe(ids_ever, "dm ht", "male").map{|patient|patient.patient_id}.uniq #- report.disease_ever_availabe(ids_ever, "HT", "male").map{|patient|patient.patient_id}.uniq - report.disease_ever_availabe(ids_ever, "DM", "male").map{|patient|patient.patient_id}.uniq
    @disease_ever_availabe_dmht_female = report.disease_ever_availabe(ids_ever, "dm ht", "female").map{|patient|patient.patient_id}.uniq #- report.disease_ever_availabe(ids_ever, "HT", "female").map{|patient|patient.patient_id}.uniq - report.disease_ever_availabe(ids_ever, "DM", "female").map{|patient|patient.patient_id}.uniq

    total_male = @total_children_registered_male + @total_adults_registered_male + @older_persons_registered_male
    
    total_female = @total_children_registered_female + @total_adults_registered_female + @older_persons_registered_female
    
    total_disease_male = (@disease_availabe_dmht_male + @disease_availabe_dm_male + @disease_availabe_ht_male + @disease_availabe_asthma_male + @disease_availabe_epilepsy_male).uniq
    total_disease_female = (@disease_availabe_dmht_female + @disease_availabe_dm_female + @disease_availabe_ht_female + @disease_availabe_asthma_female + @disease_availabe_epilepsy_female).uniq

    
    total_ever_male = @total_children_ever_registered_male + @total_adults_ever_registered_male + @older_persons_ever_registered_male
    total_ever_female = @total_children_ever_registered_female + @total_adults_ever_registered_female + @older_persons_ever_registered_female

    total_disease_ever_male = ( (@disease_ever_availabe_dmht_male || "") + (@disease_ever_availabe_dm_male || "") + (@disease_ever_availabe_ht_male || "") + (@disease_ever_availabe_asthma_male || "") + (@disease_ever_availabe_epilepsy_male || "")).uniq
    total_disease_ever_female = ( (@disease_ever_availabe_dmht_female || "") + (@disease_ever_availabe_dm_female || "") + (@disease_ever_availabe_ht_female || "") + (@disease_ever_availabe_asthma_female || "") + (@disease_ever_availabe_epilepsy_female || "")).uniq

    #  raise @disease_ever_availabe_dm_male.to_yaml
    @disease_availabe_other_male = total_male - total_disease_male.length #rescue 0
    @disease_availabe_other_female = total_female - total_disease_female.length #rescue 0
   
    @disease_ever_availabe_other_male = total_ever_male - total_disease_ever_male.length #rescue 0
   # raise  total_disease_ever_male.length.to_yaml
    @disease_ever_availabe_other_female = total_ever_female - total_disease_ever_female.length #rescue 0
     
      
    @bmi_greater_female = report.bmi(ids, 'F')
    @bmi_greater_male = report.bmi(ids, 'M')

    @bmi_greater_ever_female = report.bmi_ever(ids_ever, 'F')
    @bmi_greater_ever_male = report.bmi_ever(ids_ever, 'M')

    @smoking_female = report.smoking(ids, 'F')
    @smoking_male = report.smoking(ids, 'M')

    @smoking_ever_female = report.smoking_ever(ids_ever, 'F')
    @smoking_ever_male = report.smoking_ever(ids_ever, 'M')

    @alcohol_female = report.alcohol(ids, 'F')
    @alcohol_male = report.alcohol(ids, 'M')

    @alcohol_ever_female = report.alcohol_ever(ids_ever, 'F')
    @alcohol_ever_male = report.alcohol_ever(ids_ever, 'M')

    @insulin_female = report.patient_on_drugs(ids, "F", 'Insulin')
    @insulin_male = report.patient_on_drugs(ids, "M", 'Insulin')
    @insulin_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Insulin')
    @insulin_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Insulin')

    @glibenclamide_female = report.patient_on_drugs(ids, "F", 'Glibenclamide')
    @glibenclamide_male = report.patient_on_drugs(ids, "M", 'Glibenclamide')
    @glibenclamide_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Glibenclamide')
    @glibenclamide_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Glibenclamide')

    @metformin_female = report.patient_on_drugs(ids, "F", 'Metformin')
    @metformin_male = report.patient_on_drugs(ids, "M", 'Metformin')
    @metformin_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Metformin')
    @metformin_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Metformin')

    @amlodipine_female = report.patient_on_drugs(ids, "F", 'Amlodipine')
    @amlodipine_male = report.patient_on_drugs(ids, "M", 'Amlodipine')
    @amlodipine_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Amlodipine')
    @amlodipine_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Amlodipine')

    @captopril_female = report.patient_on_drugs(ids, "F", 'captopril')
    @captopril_male = report.patient_on_drugs(ids, "M", 'captopril')
    @captopril_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'captopril')
    @captopril_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'captopril')

    @hct_female = report.patient_on_drugs(ids, "F", 'hct')
    @hct_male = report.patient_on_drugs(ids, "M", 'hct')
    @hct_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'hct')
    @hct_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'hct')

    @phenobarbitone_female = report.patient_on_drugs(ids, "F", 'phenobarbitone')
    @phenobarbitone_male = report.patient_on_drugs(ids, "M", 'phenobarbitone')
    @phenobarbitone_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'phenobarbitone')
    @phenobarbitone_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'phenobarbitone')

    @diazepam_female = report.patient_on_drugs(ids, "F", 'Diazepam')
    @diazepam_male = report.patient_on_drugs(ids, "M", 'Diazepam')
    @diazepam_ever_female = report.patient_ever_on_drugs(ids_ever, "F", 'Diazepam')
    @diazepam_ever_male = report.patient_ever_on_drugs(ids_ever, "M", 'Diazepam')

    @bp_female = report.decrease_in_bp(ids, 'F', 'compare')
    @bp_male = report.decrease_in_bp(ids, 'M', 'compare')
    @bp_ever_female = report.decrease_in_bp(ids_ever, 'F', 'compare')
    @bp_ever_male = report.decrease_in_bp(ids_ever, 'M', 'compare')

    @low_bp_female = report.decrease_in_bp(ids, 'F', 'low')
    @low_bp_male = report.decrease_in_bp(ids, 'M', 'low')
    @low_bp_ever_female = report.decrease_in_bp(ids_ever, 'F', 'low')
    @low_bp_ever_male = report.decrease_in_bp(ids_ever, 'M', 'low')

    @glucose_female = report.decrease_in_sugar(ids, 'F')
    @glucose_male = report.decrease_in_sugar(ids, 'M')
    @glucose_ever_female = report.decrease_in_sugar(ids_ever, 'F')
    @glucose_ever_male = report.decrease_in_sugar(ids_ever, 'M')

    @asthma_female = report.asthma_ever(ids, 'F')
    @asthma_male = report.asthma_ever(ids, 'M')
    @asthma_ever_female = report.asthma_ever(ids_ever, 'F')
    @asthma_ever_male = report.asthma_ever(ids_ever, 'M')

    @non_asthmatic_male = total_male - @asthma_male
    @non_asthmatic_female = total_female - @asthma_female
    @non_asthmatic_ever_male = total_ever_male - @asthma_ever_male
    @non_asthmatic_ever_female = total_ever_female - @asthma_ever_female

    @epilepsy_female = report.epilepsy_ever(ids, 'F')
    @epilepsy_male = report.epilepsy_ever(ids, 'M')
    @epilepsy_ever_female = report.epilepsy_ever(ids_ever, 'F')
    @epilepsy_ever_male = report.epilepsy_ever(ids_ever, 'M')

    @non_epilepsy_male = total_male - @epilepsy_male
    @non_epilepsy_female = total_female - @epilepsy_female
    @non_epilepsy_ever_male = total_ever_male - @epilepsy_ever_male
    @non_epilepsy_ever_female = total_ever_female - @epilepsy_ever_female

    @controlled_male = report.controlled(ids, 'M')
    @controlled_female = report.controlled(ids, 'F')
    @controlled_ever_male = report.controlled(ids_ever, 'M')
    @controlled_ever_female = report.controlled(ids_ever, 'F')

    @comp_burns_male = report.burns_ever(ids, 'M')
    @comp_burns_female = report.burns_ever(ids, 'F')
    @comp_burns_ever_male = report.burns_ever(ids_ever, 'M')
    @comp_burns_ever_female = report.burns_ever(ids_ever, 'F')

    @comp_amputation_male = report.comp_amputation_ever(ids, 'M')
    @comp_amputation_female = report.comp_amputation_ever(ids, 'F')
    @comp_amputation_ever_male = report.comp_amputation_ever(ids_ever, 'M')
    @comp_amputation_ever_female = report.comp_amputation_ever(ids_ever, 'F')

    @comp_mi_male = report.comp_mi_ever(ids, 'M')
    @comp_mi_female = report.comp_mi_ever(ids, 'F')
    @comp_mi_ever_male = report.comp_mi_ever(ids_ever, 'M')
    @comp_mi_ever_female = report.comp_mi_ever(ids_ever, 'F')

    @comp_cardiovascular_male = report.cardiovascular_ever(ids, 'M')
    @comp_cardiovascular_female = report.cardiovascular_ever(ids, 'F')
    @comp_cardiovascular_ever_male = report.cardiovascular_ever(ids_ever, 'M')
    @comp_cardiovascular_ever_female = report.cardiovascular_ever(ids_ever, 'F')

    @comp_blind_male = report.blind_ever(ids, 'M')
    @comp_blind_female = report.blind_ever(ids, 'F')
    @comp_blind_ever_male = report.blind_ever(ids_ever, 'M')
    @comp_blind_ever_female = report.blind_ever(ids_ever, 'F')
   end
 
    @dead_ever_male = report.dead_ever(ids_ever, "male")# rescue 0
    @dead_ever_female = report.dead_ever(ids_ever, "female")# rescue 0

     if params[:type] != "ccc"
      @dead_ever = @dead_ever_male + @dead_ever_female
      @dead_female = report.dead(ids, "female")# rescue 0
      @dead_male = report.dead(ids, "male")# rescue 0
      @dead = @dead_male + @dead_female
      @discharged_ever = report.discharged_ever(ids_ever) rescue 0
      @discharged = report.discharged(ids) rescue 0
     end

    @transfer_out_ever_male = report.transfer_out_ever(ids_ever, "male") #rescue 0
    @transfer_out_ever_female = report.transfer_out_ever(ids_ever, "female") #rescue 0
   # raise @transfer_out_ever_male.to_yaml

    @transfer_out_ever = @transfer_out_ever_male + @transfer_out_ever_female
    
    @transfer_out_male = report.transfer_out(ids_ever, "male")
    @transfer_out_female = report.transfer_out(ids_ever, "female")
    @transfer_out = @transfer_out_male + @transfer_out_female

    @stopped_treatment_ever_male = report.stopped_treatment_ever(ids_ever, "male") #rescue 0
    @stopped_treatment_ever_female = report.stopped_treatment_ever(ids_ever, "female")
    @stopped_treatment_male = report.stopped_treatment(ids, "male")
    @stopped_treatment_female = report.stopped_treatment(ids, "female")

    #raise report.attending_ever(ids, "female").to_yaml

   #- @dead_ever_female - @transfer_out_ever_female - @stopped_treatment_ever_female

    @not_attend_male = report.not_attending_ever(ids_ever, "male")
    @not_attend_female = report.not_attending_ever(ids_ever, "female")
    @lost_followup_male = report.lost_followup_ever(ids_ever, "male")
    @lost_followup_female = report.lost_followup_ever(ids_ever, "female")


    if params[:type] != "ccc"
    @stopped_treatment_ever = report.stopped_treatment_ever(ids_ever).length rescue 0
    @stopped_treatment = report.stopped_treatment(ids).length  rescue 0
   
    @defaulters_ever = report.defaulters_ever(ids_ever) rescue 0
    #@defaulters_ever = @defaulters_ever - @transfer_out_ever.to_i - @stopped_treatment_ever.to_i - @discharged_ever.to_i
    @defaulters = report.defaulters(ids) rescue 0
    #@defaulters = @defaulters - @transfer_out.to_i - @stopped_treatment.to_i - @discharged.to_i

    #@defaulters_ever = 0 if @defaulters_ever.to_i < 0
    #@defaulters = 0 if @defaulters.to_i < 0

    @alive_ever = @total_ever_registered.to_i - @defaulters_ever.to_i - @transfer_out_ever.to_i - @stopped_treatment_ever.to_i - @discharged_ever.to_i

    @alive = @total_registered.to_i - @defaulters.to_i - @transfer_out.to_i - @stopped_treatment.to_i - @discharged.to_i

    @on_diet_ever = report.diet_only(ids_ever, "cumulative")

    @on_diet = report.diet_only(ids)
    @total_women_registered = report.total_women_registered(ids) rescue 0

    @total_women_ever_registered = report.total_women_ever_registered(ids_ever) rescue 0

    @total_men_registered = report.total_men_registered(ids) rescue 0
    @total_men_ever_registered = report.total_men_ever_registered(ids_ever) rescue 0

    @background_retinapathy_ever = report.background_retinapathy_ever rescue 0

    @background_retinapathy = report.background_retinapathy rescue 0

    @ploriferative_retinapathy_ever = report.ploriferative_retinapathy_ever rescue 0

    @ploriferative_retinapathy = report.ploriferative_retinapathy rescue 0

    @end_stage_retinapathy_ever = report.end_stage_retinapathy_ever rescue 0

    @end_stage_retinapathy = report.end_stage_retinapathy rescue 0

    @maculopathy_ever = report.maculopathy_ever rescue 0

    @maculopathy = report.maculopathy rescue 0

    @diabetic_retinopathy_ever = @background_retinapathy_ever +
      @ploriferative_retinapathy_ever +
      @end_stage_retinapathy_ever +
      @maculopathy_ever

    @diabetic_retinopathy = @background_retinapathy +
      @ploriferative_retinapathy +
      @end_stage_retinapathy +
      @maculopathy
    else
      @attending_male = total_ever_male - @not_attend_male - @stopped_treatment_ever_male - @lost_followup_male - @transfer_out_ever_male - @dead_ever_male
      @attending_female = total_ever_female - @not_attend_female - @stopped_treatment_ever_female - @lost_followup_female - @transfer_out_ever_female - @dead_ever_female    #- @dead_ever_male - @transfer_out_ever_male - @stopped_treatment_ever_male
    end
   

    render :template => "/cohort_tool/ccc_cohort", :layout => "application" and return if params[:type] == "ccc"
    render :template => "/cohort_tool/cohort", :layout => "application"
  end


  def epilepsy_report
    @quarter = params[:quarter]
    @start_date, @end_date = Report.generate_cohort_date_range(@quarter)
    @user = User.find(params["user_id"]) rescue nil
    @logo = CoreService.get_global_property_value('logo').to_s

    report = Reports::CohortDm.new(@start_date, @end_date)
    @facility = get_global_property_value("facility.name") rescue ""

    @specified_period = report.specified_period

#Making sure we report only patients gone through epilepsy program
    @total_registered = report.total_registered("EPILEPSY CLINIC VISIT").length rescue 0
    ids = report.total_registered("EPILEPSY CLINIC VISIT").map{|patient|patient.patient_id.to_s}.join(',') rescue ""
    @total_ever_registered = report.total_ever_registered("EPILEPSY CLINIC VISIT").length rescue 0
     ids_ever = report.total_ever_registered("EPILEPSY CLINIC VISIT").map{|patient|patient.patient_id.to_s}.join(',') rescue ""

    @confirmed = report.epilepsy_type("Confirm diagnosis of epilepsy", "yes") rescue 0
    @confirmed_ever = report.epilepsy_type_ever("Confirm diagnosis of epilepsy", "yes") rescue 0

    @generalized = report.epilepsy_type("Type of epilepsy", "Generalised") rescue 0
    @generalized_ever = report.epilepsy_type_ever("Type of epilepsy", "Generalised") rescue 0

    @non_confirmed = @total_registered - @confirmed
    @non_confirmed_ever = @total_ever_registered - @confirmed_ever

    @focal_seizure = @confirmed - @generalized
    @focal_seizure_ever = @confirmed_ever - @generalized_ever

    @atomic = report.epilepsy_type("Generalised", "atomic") rescue 0
    @atomic_ever = report.epilepsy_type_ever("Generalised", "atomic") rescue 0

    @chlonic = report.epilepsy_type("Generalised", "chlonic") rescue 0
    @chlonic_ever = report.epilepsy_type_ever("Generalised", "chlonic") rescue 0

    @myclonic = report.epilepsy_type("Generalised", "myclonic") rescue 0
    @myclonic_ever = report.epilepsy_type_ever("Generalised", "myclonic") rescue 0

    @absence = report.epilepsy_type("Generalised", "absence") rescue 0
    @absence_ever = report.epilepsy_type_ever("Generalised", "absence") rescue 0

    @tonic_clonic = report.epilepsy_type("Generalised", "Tonic Clonic") rescue 0
    @tonic_clonic_ever = report.epilepsy_type_ever("Generalised", "Tonic Clonic") rescue 0

    @simplex = report.epilepsy_type("Focal seizure", "Simplex") rescue 0
    @simplex_ever = report.epilepsy_type_ever("Focal seizure", "Simplex") rescue 0

    @complex = report.epilepsy_type("Focal seizure", "Complex") rescue 0
    @complex_ever = report.epilepsy_type_ever("Focal seizure", "Complex") rescue 0

    @psychogenic = report.non_epileptic("Condition", "Psychogenic") rescue 0
    @psychogenic_ever = report.non_epileptic_ever("Condition", "Psychogenic") rescue 0

    @febrile_seizure = report.non_epileptic("Condition", "Febrile seizure") rescue 0
    @febrile_seizure_ever = report.non_epileptic_ever("Condition", "Febrile seizure") rescue 0

    @syncope = report.non_epileptic("Condition", "Syncope") rescue 0
    @syncope_ever = report.non_epileptic_ever("Condition", "Syncope") rescue 0

    @burns = report.epilepsy_type("Burns", "yes") rescue 0
    @burns_ever = report.epilepsy_type_ever("Burns", "yes") rescue 0

    @injuries = report.epilepsy_type("Head injury", "Yes") rescue 0
    @injuries_ever = report.epilepsy_type_ever("Head injury", "Yes") rescue 0

    @drug_related = report.epilepsy_type("Cause of Seizure", "drug/alcohol withdrawal") rescue 0
    @drug_related_ever = report.epilepsy_type_ever("Cause of Seizure", "drug/alcohol withdrawal") rescue 0

    @hyperactivity = report.epilepsy_type("hyperactivity", "yes") rescue 0
    @hyperactivity_ever = report.epilepsy_type_ever("hyperactivity", "yes") rescue 0

    @psychosis = report.epilepsy_type("psychosis", "yes") rescue 0
    @psychosis_ever = report.epilepsy_type_ever("psychosis", "yes") rescue 0

    @total_adults_registered = report.total_adults_registered(ids) rescue 0

    @total_adults_ever_registered = report.total_adults_ever_registered(ids_ever) rescue 0

    @total_children_registered = report.total_children_registered(ids) rescue 0

    @total_children_ever_registered = report.total_children_ever_registered(ids_ever) rescue 0

    @total_men_registered = report.total_men_registered(ids) rescue 0
    @total_men_ever_registered = report.total_men_ever_registered(ids_ever) rescue 0


    @total_adult_men_registered = report.total_adult_men_registered(ids) rescue 0

    @total_adult_men_ever_registered = report.total_adult_men_ever_registered(ids_ever) rescue 0


    @total_boy_children_registered = report.total_boy_children_registered(ids) rescue 0

    @total_boy_children_ever_registered = report.total_boy_children_ever_registered(ids_ever)  rescue 0


    @total_women_registered = report.total_women_registered(ids) rescue 0

    @total_women_ever_registered = report.total_women_ever_registered(ids_ever) rescue 0


    @total_adult_women_registered = report.total_adult_women_registered(ids) rescue 0

    @total_adult_women_ever_registered = report.total_adult_women_ever_registered(ids_ever) rescue 0


    @total_girl_children_registered = report.total_girl_children_registered(ids) rescue 0

    @total_girl_children_ever_registered = report.total_girl_children_ever_registered(ids_ever) rescue 0


    @tb_known_ever = report.tb_known_ever(ids_ever) rescue 0

    @tb_known = report.tb_known(ids) rescue 0

    @tb_after_diabetes_ever = report.tb_after_diabetes_ever(ids_ever) rescue 0

    @tb_after_diabetes = report.tb_after_diabetes(ids) rescue 0

    @tb_before_diabetes_ever = report.tb_before_diabetes_ever(ids_ever) rescue 0

    @tb_before_diabetes = report.tb_before_diabetes(ids) rescue 0

    @tb_unknown_ever = report.tb_unkown_ever(ids_ever) rescue 0

    @tb_unknown = report.tb_unkown(ids) rescue 0

    @no_tb_ever = report.no_tb_ever(ids_ever) rescue 0

    @no_tb = report.no_tb(ids) rescue 0

    @tb_ever = report.tb_ever(ids_ever) rescue 0

    @tb = report.tb(ids) rescue 0

    @reactive_not_on_art_ever = report.reactive_not_on_art_ever(ids_ever) rescue 0

    @reactive_not_on_art = report.reactive_not_on_art(ids) rescue 0

    @reactive_on_art_ever = report.reactive_on_art_ever(ids_ever) rescue 0

    @reactive_on_art = report.reactive_on_art(ids) rescue 0

    @non_reactive_ever = report.non_reactive_ever(ids_ever) rescue 0

    @non_reactive = report.non_reactive(ids) rescue 0

    @unknown_ever = (@total_ever_registered.to_i - @non_reactive_ever.to_i -
        @reactive_on_art_ever.to_i - @reactive_not_on_art_ever.to_i)

    @unknown = (@total_registered.to_i - @non_reactive.to_i -
        @reactive_on_art.to_i - @reactive_not_on_art.to_i)

    @dead_ever = report.dead_ever(ids_ever) #rescue 0

    #raise report.dead(ids).to_yaml
    @dead = report.dead(ids) #rescue 0

    @discharged_ever = report.discharged_ever(ids_ever) rescue 0
    @discharged =report.discharged(ids) rescue 0

    @transfer_out_ever = report.transfer_out_ever(ids_ever) rescue 0

    @transfer_out = report.transfer_out(ids) rescue 0

    @stopped_treatment_ever = report.stopped_treatment_ever(ids_ever)# rescue 0

    @stopped_treatment = report.stopped_treatment(ids) # rescue 0
  

    @defaulters_ever = report.defaulters_ever(ids_ever) rescue 0
    @defaulters_ever = @defaulters_ever - @transfer_out_ever.to_i - @stopped_treatment_ever.to_i - @discharged_ever.to_i

    @defaulters = report.defaulters(ids) rescue 0
    @defaulters = @defaulters - @transfer_out.to_i - @stopped_treatment.to_i - @discharged.to_i

    @defaulters_ever = 0 if @defaulters_ever.to_i < 0
    @defaulters = 0 if @defaulters.to_i < 0

    @alive_ever = @total_ever_registered.to_i - @defaulters_ever.to_i - @transfer_out_ever.to_i - @stopped_treatment_ever.to_i - @discharged_ever.to_i

    @alive = @total_registered.to_i - @defaulters.to_i - @transfer_out.to_i - @stopped_treatment.to_i - @discharged.to_i

    render :layout => "application"
  end

end
