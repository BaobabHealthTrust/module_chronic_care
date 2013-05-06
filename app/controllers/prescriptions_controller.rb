class PrescriptionsController < GenericPrescriptionsController

	def prescribe
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
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
end
