class PrescriptionsController < GenericPrescriptionsController

	def prescribe
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
		@user = User.find(params[:user_id]) rescue nil?
    @patient_diagnoses = current_diagnoses(@patient.person.id)
    @current_weight = Vitals.get_patient_attribute_value(@patient, "current_weight")
		@current_height = Vitals.get_patient_attribute_value(@patient, "current_height")
  end

  def current_diagnoses(patient_id)
    patient = Patient.find(patient_id)
    patient.encounters.current.all(:include => [:observations]).map{|encounter|
      encounter.observations.all(
        :conditions => ["obs.concept_id = ? OR obs.concept_id = ?",
          ConceptName.find_by_name("DIAGNOSIS").concept_id,
          ConceptName.find_by_name("DIAGNOSIS, NON-CODED").concept_id])
    }.flatten.compact
  end

  def dm_drugs
		#search_string = (params[:search_string] || '').upcase
		hypertension_medication_concept       = ConceptName.find_by_name("HYPERTENSION MEDICATION").concept_id
		diabetes_medication_concept       = ConceptName.find_by_name("DIABETES MEDICATION").concept_id
		cardiac_medication_concept       = ConceptName.find_by_name("CARDIAC MEDICATION").concept_id
		kidney_failure_medication_concept       = ConceptName.find_by_name("KIDNEY FAILURE CARDIAC MEDICATION").concept_id
		#@drug_concepts = ConceptName.find_by_sql("SELECT * FROM concept_set
		#INNER JOIN drug ON drug.concept_id = concept_set.concept_id WHERE drug.retired = 0 AND
		#concept_set IN (#{hypertension_medication_concept}, #{diabetes_medication_concept}, #{cardiac_medication_concept}, #{kidney_failure_medication_concept})")



    search_string = (params[:search_string] || '').upcase
    filter_list = params[:filter_list].split(/, */) rescue []
    @drug_concepts = ConceptName.find(:all,
      :select => "concept_name.name",
      :joins => "INNER JOIN drug ON drug.concept_id = concept_name.concept_id AND drug.retired = 0
								 INNER JOIN concept_set ON concept_set.concept_id = concept_name.concept_id",
      :conditions => ["concept_name.name LIKE ? AND concept_set IN (#{hypertension_medication_concept}, #{diabetes_medication_concept}, #{cardiac_medication_concept}, #{kidney_failure_medication_concept})", '%' + search_string + '%'],:group => 'drug.concept_id')
    render :text => "<li>" + @drug_concepts.map{|drug_concept| drug_concept.name }.uniq.join("</li><li>") + "</li>"
  end

    def new_prescription

    @patient = Patient.find(params[:patient_id])
    @partial_name = 'drug_set'
    @partial_name = params[:screen] unless params[:screen].blank?
    @drugs = Drug.find(:all,:limit => 20)
    @drug_sets = {}
    @set_names = {}
    @set_descriptions = {}

    GeneralSet.find_all_by_status("active").each do |set|

      @drug_sets[set.set_id] = {}
      @set_names[set.set_id] = set.name
      @set_descriptions[set.set_id] = set.description

      dsets = DrugSet.find_all_by_set_id(set.set_id)
      dsets.each do |d_set|

        @drug_sets[set.set_id][d_set.drug_inventory_id] = {}
        drug = Drug.find(d_set.drug_inventory_id)
        @drug_sets[set.set_id][d_set.drug_inventory_id]["drug_name"] = drug.name
        @drug_sets[set.set_id][d_set.drug_inventory_id]["units"] = drug.units
        @drug_sets[set.set_id][d_set.drug_inventory_id]["duration"] = d_set.duration
        @drug_sets[set.set_id][d_set.drug_inventory_id]["frequency"] = d_set.frequency
      end
    end

    render :layout => false
  end

  def search_for_drugs
    drugs = {}
    Drug.find(:all, :conditions => ["name LIKE (?)",
        "#{params[:search_str]}%"],:order => 'name',:limit => 20).map do |drug|
      drugs[drug.id] = { :name => drug.name,:dose_strength =>drug.dose_strength || 1, :unit => drug.units }
    end
    render :text => drugs.to_json
  end

  def prescribes

    @patient    = Patient.find(params["patient_id"]) rescue nil
  
    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

		encounter  = current_prescription_encounter(@patient, session_date, params[:user_id])
    encounter.encounter_datetime = session_date
    encounter.save

    params[:drug_formulations] = (params[:drug_formulations] || []).collect{|df| eval(df) } || {}

    params[:drug_formulations].each do |prescription|

      prescription[:prn] = 0 if prescription[:prn].blank?
      auto_expire_date = session_date.to_date + (prescription[:duration].sub(/days/i, "").strip).to_i.days
      drug = Drug.find(prescription[:drug_id])

      DrugOrder.write_order(encounter, @patient, nil, drug, session_date, auto_expire_date, drug.dose_strength,
        prescription[:frequency], prescription[:prn].to_i)
    end

    #if (@patient)
		#	redirect_to next_task(@patient) and return
		#else
			redirect_to "/patients/treatment_dashboard?patient_id=#{params[:patient_id]}&user_id=#{params[:user_id]}"
  end


end
