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

end
