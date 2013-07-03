  module Vitals 
	include CoreService
  #include Openmrs

			def self.get_patient_attribute_value(patient, attribute_name, session_date = Date.today)

				sex = patient.gender.upcase
				sex = 'M' if patient.gender.upcase == 'MALE'
				sex = 'F' if patient.gender.upcase == 'FEMALE'

				case attribute_name.upcase
				when "AGE"
					return patient.age
				when "RESIDENCE"
					return patient.address
				when "SYSTOLIC BLOOD PRESSURE"
					return self.current_vitals(patient, attribute_name).value_numeric
				when "DIASTOLIC BLOOD PRESSURE"
					return self.current_vitals(patient, attribute_name).value_numeric
				when "PATIENT HAS DIABETES"
					return self.current_vitals(patient, attribute_name).value_coded
				when "APPOINTMENT DATE"
					return self.current_vitals(patient, attribute_name).value_datetime rescue ""
				when "CURRENT_HEIGHT"
					obs = patient.person.observations.before((session_date + 1.days).to_date).question("HEIGHT (CM)").all
					return obs.first.answer_string.to_f rescue 0
				when "CURRENT_WEIGHT"
					obs = patient.person.observations.before((session_date + 1.days).to_date).question("WEIGHT (KG)").all
					return obs.first.answer_string.to_f rescue 0
				when "INITIAL_WEIGHT"
					obs = patient.person.observations.old(1).question("WEIGHT (KG)").all
					return obs.last.answer_string.to_f rescue 0
				when "INITIAL_HEIGHT"
					obs = patient.person.observations.old(1).question("HEIGHT (CM)").all
					return obs.last.answer_string.to_f rescue 0
				when "INITIAL_BMI"
					obs = patient.person.observations.old(1).question("BMI").all
					return obs.last.answer_string.to_f rescue nil
				when "MIN_WEIGHT"
					return WeightHeight.min_weight(sex, patient.age_in_months).to_f
				when "MAX_WEIGHT"
					return WeightHeight.max_weight(sex, patient.age_in_months).to_f
				when "MIN_HEIGHT"
					return WeightHeight.min_height(sex, patient.age_in_months).to_f
				when "MAX_HEIGHT"
					return WeightHeight.max_height(sex, patient.age_in_months).to_f
				end

			end

			def self.expectect_flow_rate(patient)
				age = patient.age
				sex = patient.gender.downcase
				sex = 'm' if patient.gender.upcase == 'male'
				sex = 'f' if patient.gender.upcase == 'female'
				current_height = self.get_patient_attribute_value(patient, "current_height")
				if (age < 18)
					pefr = ((current_height - 100) * 5) + 100;
				end
				if age >= 18 and sex == "m"
					current_height /= 100;
					pefr = (((current_height * 5.48) + 1.58) - (age * 0.041)) * 60;
				end
				if ((age >= 18) && (sex == "f"))
						current_height /= 100;
						pefr = (((current_height * 3.72) + 2.24) - (age * 0.03)) * 60;
				end
				return pefr
			end

        def self.current_treatment_encounter(patient, provider, date = Time.now())
         #raise user_person_id.to_yaml
				#types = Encounter.find_by_sql("select * from encounter_type where name = 'TREATMENT'").first.encounter_type_id
       
				encounter = patient.encounters.find(:first,:conditions =>["encounter_datetime BETWEEN ? AND ? AND encounter_type = ?",
													date.to_date.strftime('%Y-%m-%d 00:00:00'),
													date.to_date.strftime('%Y-%m-%d 23:59:59'),
													EncounterType.find_by_name("TREATMENT").id])
				encounter ||= patient.encounters.create(:encounter_type => EncounterType.find_by_name("TREATMENT").id,:encounter_datetime => date, :provider_id => provider)
			end

			def self.current_vitals(patient, vital_sign, session_date = Time.now())
				concept = ConceptName.find_by_sql("select concept_id from concept_name where name = '#{vital_sign}' and voided = 0").first.concept_id
				Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{patient.id}'
                    AND DATE(obs_datetime) <= '#{session_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first rescue nil
			end

      def self.todays_vitals(patient, vital_sign, session_date = Time.now())
				concept = ConceptName.find_by_sql("select concept_id from concept_name where name = '#{vital_sign}' and voided = 0").first.concept_id

        Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{patient.id}'
                    AND DATE(obs_datetime) = '#{session_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first rescue nil
        
			end

			def self.current_encounter(patient, enc, concept, session_date = Date.today)
				concept = ConceptName.find_by_name(concept).concept_id
        
				encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  session_date ,patient.id, EncounterType.find_by_name(enc).id]).encounter_id rescue nil
				Observation.find(:all, :order => "obs_datetime DESC,date_created DESC", :conditions => ["encounter_id = ? AND concept_id = ?", encounter, concept]) rescue nil
			end

	def self.drugs_given_on(patient, date = Date.today)
    clinic_encounters = ["APPOINTMENT", "VITALS","ART_INITIAL","HIV RECEPTION",
      "ART VISIT","TREATMENT","DISPENSING",'ART ADHERENCE','HIV STAGING']
    encounter_type_ids = EncounterType.find_all_by_name(clinic_encounters).collect{|e|e.id}

    latest_encounter_date = Encounter.find(:first,
        :conditions =>["patient_id = ? AND encounter_datetime >= ?
        AND encounter_datetime <=? AND encounter_type IN(?)",
        patient.id,date.strftime('%Y-%m-%d 00:00:00'),
        date.strftime('%Y-%m-%d 23:59:59'),encounter_type_ids],
        :order =>"encounter_datetime DESC").encounter_datetime rescue nil

    return [] if latest_encounter_date.blank?

    start_date = latest_encounter_date.strftime('%Y-%m-%d 00:00:00')
    end_date = latest_encounter_date.strftime('%Y-%m-%d 23:59:59')

    concept_id = Concept.find_by_name('AMOUNT DISPENSED').id
    Order.find(:all,:joins =>"INNER JOIN obs ON obs.order_id = orders.order_id",
        :conditions =>["obs.person_id = ? AND obs.concept_id = ?
        AND obs_datetime >=? AND obs_datetime <=?",
        patient.id,concept_id,start_date,end_date],
        :order =>"obs_datetime")
  end

  def self.occupation(patient)
    specified_id = PersonAttributeType.find_by_name("Occupation").person_attribute_type_id
    return PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", patient.person.id, specified_id]) #rescue nil
  end

   def self.guardian(patient)
    person_id = Relationship.find(:first,:order => "date_created DESC",
      :conditions =>["person_a = ?",patient.person.id]).person_b rescue nil
    guardian_name = name(Person.find(person_id))
    guardian_name rescue nil
  end

  def self.name(person)
    "#{person.names.first.given_name} #{person.names.first.family_name}".titleize rescue nil
  end

  def self.is_transfer_in(patient)
    patient_transfer_in = patient.person.observations.recent(1).question("TYPE OF PATIENT").all rescue nil
    return false if patient_transfer_in.blank?
    return true
  end
end

