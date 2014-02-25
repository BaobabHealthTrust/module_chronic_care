class Reports::CohortDm

  attr_accessor :start_date, :end_date

  # Initialize class
  def initialize(start_date, end_date)
    @start_date = "#{start_date} 00:00:00"
    @end_date = "#{end_date} 23:59:59"
  	@diabetes_program_id = Program.find_by_name('DIABETES PROGRAM').id
		@hypertensition_medication_id  = Concept.find_by_name("HYPERTENSION MEDICATION").id
		@diabetes_id                   = Concept.find_by_name("DIABETES MEDICATION").id
    @asthma_id             = Concept.find_by_name("ASTHMA MEDICATION").id
    @epilepsy_id             = Concept.find_by_name("EPILEPSY MEDICATION").id
    @program_id = Program.find_by_name('CHRONIC CARE PROGRAM').id


    # Metformin And Glibenclamide
		# Patients on metformin and glibenclamide: up to end date


    names = ["PATIENT DIED", "PATIENT TRANSFERRED OUT", "TREATMENT STOPPED"]
    @states = []
    names.each { |name|
      concept_name = ConceptName.find_all_by_name(name)
      @states << ProgramWorkflowState.find(:first, :conditions => ["concept_id IN (?)",concept_name.map{|c|c.concept_id}] ).program_workflow_state_id
    }
    @states = @states.join(',')
        

  	@ids_for_patients_on_metformin_and_glibenclamide_ever = Patient.find(:all,
      :include =>{:orders => {:drug_order =>{:drug => {}}}},
      :conditions => ['(drug.name LIKE ? OR drug.name LIKE ?)
													 									AND patient.voided = 0 AND patient.date_created <= ?', "%metformin%",
        "%glibenclamide%", @end_date]
    ).map{|patient| patient.patient_id}.uniq

												
		# Patients on metformin and glibenclamide: between @start_date and @end_date

  	@ids_for_patients_on_metformin_and_glibenclamide = Patient.find(:all,
      :include =>{:orders => {:drug_order =>{:drug => {}}}},
      :conditions => ['(drug.name LIKE ? OR drug.name LIKE ?)
													 									AND patient.voided = 0 AND patient.date_created >= ?
                                            AND patient.date_created <= ?',
        "%metformin%", "%glibenclamide%",
        @start_date, @end_date]
    ).map{|patient| patient.patient_id}.uniq
    

    # Insulin
  	@ids_for_patients_on_insulin_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'insulin')							 			 
  	@ids_for_patients_on_insulin = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'insulin')

    # Metformin
  	@ids_for_patients_on_metformin_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'metformin')  							 			 
  	@ids_for_patients_on_metformin = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'metformin')
  	
    # Glibenclamide
  	@ids_for_patients_on_glibenclamide_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'glibenclamide')  							 			 
  	@ids_for_patients_on_glibenclamide = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'glibenclamide')

    # Lente_insulin
  	@ids_for_patients_on_lente_insulin_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'lente', 'insulin')  							 			 
  	@ids_for_patients_on_lente_insulin = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'lente', 'insulin')

    # Soluble insulin ever
  	@ids_for_patients_on_soluble_insulin_ever = ids_for_patient_on_drug_upto_end_date(@end_date, 'soluble', 'insulin')  							 			 
  	@ids_for_patients_on_soluble_insulin = ids_for_patient_on_drug_btn_dates(@start_date, @end_date, 'soluble', 'insulin')
  	
    # Complications
		@complications_hash_upto_end_date = Hash.new(0)
		@complications_hash_btn_dates = Hash.new(0)
		
		@complications_hash_upto_end_date = Patient.count(:all,
      :include => { :encounters => {:observations => {:answer_concept => {:concept_names => {}}}}},
      :conditions => ["patient.date_created <= ?", @end_date],
      :group => "concept_name.name")
											
		@complications_hash_btn_dates = Patient.count(:all,
      :include => { :encounters => {:observations => {:answer_concept => {:concept_names => {}}}}},
      :conditions => ["patient.date_created >= ? AND patient.date_created <= ?",
        @start_date, @end_date],
      :group => "concept_name.name")
  end

  # Metformin
  # Model access test function
  def specified_period
    @range = [@start_date, @end_date]
  end

  # Get all patients registered in specified period
  def total_registered(encounter_type=nil)
    
    Patient.find_by_sql("
                  SELECT DISTINCT p.patient_id FROM patient p
                  WHERE p.voided = 0
                  AND p.date_created <= '#{@end_date}'
                  AND p.date_created >= '#{@start_date}'")
  end

  def total_adults_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["patient.date_created >= ?
																		AND patient.date_created <= ? AND " +
          "COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
                                    AND patient.patient_id IN (#{ids})
																		AND patient.voided = 0", @start_date, @end_date]
    )
  end
  def disease_availabe(ids, type, sex)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(p.gender) = '#{sex.upcase}'
                                    OR UCASE(p.gender) = '#{patient_initial}')"
    end
   
    encounter = EncounterType.find_by_name("Vitals").id
    if type.upcase == "HT"
      concept = ConceptName.find_by_name("cardiovascular system diagnosis").concept_id
      @orders = Order.find_by_sql("SELECT DISTINCT(o.person_id) FROM obs o
                                  INNER JOIN person p ON p.person_id = o.person_id
                                  INNER JOIN patient ON patient.patient_id = o.person_id
                                  INNER JOIN encounter e ON e.encounter_id = o.encounter_id\
                                  WHERE patient.voided = 0 AND o.voided = 0 AND patient.patient_id IN (#{ids}) 
                                  #{categorise} 
                                  AND o.concept_id = #{concept}
                                 AND e.encounter_type = #{encounter}
                                 AND o.value_coded != (SELECT concept_id FROM concept_name WHERE name = 'Normal')
                                 GROUP BY patient.patient_id").length #rescue 0

    elsif type.upcase == "DM"
      ht_concept = ConceptName.find_by_name("cardiovascular system diagnosis").concept_id
      concept = ConceptName.find_by_name("Patient has Diabetes").concept_id
=begin
      @orders = Order.find_by_sql("SELECT DISTINCT(o.person_id) FROM obs o
                                  INNER JOIN person p ON p.person_id = o.person_id
                                  INNER JOIN patient ON patient.patient_id = o.person_id
                                  INNER JOIN orders ON orders.patient_id = patient.patient_id
                                  INNER JOIN encounter e ON e.encounter_id = o.encounter_id\
                                  WHERE patient.voided = 0 AND o.voided = 0 AND orders.voided = 0 AND patient.patient_id IN (#{ids}) AND \
                                  DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'  \
                                  #{categorise} AND  DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date + "'  \
                                  AND patient.patient_id NOT IN (SELECT person_id FROM obs  WHERE concept_id = #{ht_concept}
                                  AND value_coded != (SELECT concept_id FROM concept_name WHERE name = 'Normal'))
                                  AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
                                 concept_set = #{@diabetes_id})
                                 GROUP BY patient.patient_id").length #rescue 0
=end
                @orders = Order.find_by_sql("SELECT DISTINCT(o.person_id) FROM obs o
                                  INNER JOIN person p ON p.person_id = o.person_id
                                  INNER JOIN patient ON patient.patient_id = o.person_id
                                  INNER JOIN encounter e ON e.encounter_id = o.encounter_id\
                                  WHERE patient.voided = 0 AND o.voided = 0 AND patient.patient_id IN (#{ids}) 
                                  #{categorise} 
                                  AND patient.patient_id NOT IN (SELECT person_id FROM obs  WHERE concept_id = #{ht_concept}
                                  AND value_coded != (SELECT concept_id FROM concept_name WHERE name = 'Normal'))
                                 GROUP BY patient.patient_id").length #rescue 0
    elsif type.upcase == "ASTHMA"
      @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders
                                INNER JOIN person p ON p.person_id = orders.patient_id
                                INNER JOIN patient ON patient.patient_id = orders.patient_id \
                                WHERE patient.voided = 0 AND patient.patient_id IN (#{ids}) 
                                #{categorise} 
                                AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
                                concept_set = #{@asthma_id})
                                GROUP BY patient_id").length rescue 0
    elsif type.upcase == "EPILEPSY"
      @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders
                                INNER JOIN person p ON p.person_id = orders.patient_id
                                INNER JOIN patient ON patient.patient_id = orders.patient_id \
                                WHERE patient.voided = 0 AND patient.patient_id IN (#{ids}) 
                                #{categorise} 
                                AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
                                concept_set = #{@epilepsy_id})
                                GROUP BY patient_id").length rescue 0
    elsif type.upcase == "DM HT"
      ht_concept = ConceptName.find_by_name("cardiovascular system diagnosis").concept_id
      dm_concept = ConceptName.find_by_name("Patient has Diabetes").concept_id
      @orders = Order.find_by_sql("SELECT o.person_id FROM obs o
                                  INNER JOIN person p ON p.person_id = o.person_id
                                  INNER JOIN patient ON patient.patient_id = o.person_id
                                  INNER JOIN orders ON orders.patient_id = patient.patient_id
                                  WHERE patient.voided = 0 AND o.voided = 0 AND orders.voided = 0 AND patient.patient_id IN (#{ids}) 
                                  #{categorise} AND (o.concept_id = #{dm_concept}
                                  AND o.value_coded != (SELECT concept_id FROM concept_name WHERE name = 'Normal'))
                                  AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
                                  concept_set = #{@diabetes_id})
                                  GROUP BY patient.patient_id").length #rescue 0
    elsif type.upcase == "OTHER"
      @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders
                                      INNER JOIN person p ON p.person_id = orders.patient_id
                                      INNER JOIN patient ON patient.patient_id = orders.patient_id \
                                      WHERE patient.voided = 0 AND patient.patient_id IN (#{ids})
                                      #{categorise} 
																			AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
																			concept_set NOT IN (#{@hypertensition_medication_id}, #{@asthma_id},#{@diabetes_id}, #{@epilepsy_id})) \
                                      GROUP BY patient_id").length rescue 0
    end
    return @orders
  end

  def disease_ever_availabe(ids, type, sex)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(p.gender) = '#{sex.upcase}'
                                    OR UCASE(p.gender) = '#{patient_initial}')"
    end
    
    if type.upcase == "HT"
      concept = ConceptName.find_by_name("cardiovascular system diagnosis").concept_id
      encounter = EncounterType.find_by_name("Vitals").id

      @orders = Observation.find_by_sql("SELECT o.person_id FROM obs o
                                      INNER JOIN person p ON p.person_id = o.person_id
                                      INNER JOIN patient ON patient.patient_id = o.person_id
                                      INNER JOIN encounter e ON e.encounter_id = o.encounter_id\
                                      WHERE patient.voided = 0 AND o.voided = 0 AND patient.patient_id IN (#{ids}) 
																			 #{categorise}
                                      AND o.concept_id = #{concept}
                                      AND e.encounter_type = #{encounter}
                                     AND o.value_coded != (SELECT concept_id FROM concept_name WHERE name = 'Normal')
                                     GROUP BY patient.patient_id").length #rescue 0
      # raise @orders.to_yaml
    elsif type.upcase == "DM"
      ht_concept = ConceptName.find_by_name("cardiovascular system diagnosis").concept_id
=begin
      @orders = Order.find_by_sql("SELECT o.person_id FROM obs o
                                  INNER JOIN person p ON p.person_id = o.person_id
                                  INNER JOIN patient ON patient.patient_id = o.person_id
                                  INNER JOIN orders ON orders.patient_id = patient.patient_id
                                  INNER JOIN encounter e ON e.encounter_id = o.encounter_id\
                                  WHERE patient.voided = 0 AND o.voided = 0 AND orders.voided = 0 AND patient.patient_id IN (#{ids}) AND \
                                  DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'  \
                                  #{categorise} 
                                  AND patient.patient_id NOT IN (SELECT person_id FROM obs  WHERE concept_id = #{ht_concept}
                                  AND value_coded != (SELECT concept_id FROM concept_name WHERE name = 'Normal'))
                                  AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
                                 concept_set = #{@diabetes_id})
                                 GROUP BY patient.patient_id").length #rescue 0
=end
      @orders = Order.find_by_sql("SELECT o.person_id FROM obs o
                                  INNER JOIN person p ON p.person_id = o.person_id
                                  INNER JOIN patient ON patient.patient_id = o.person_id
                                  INNER JOIN encounter e ON e.encounter_id = o.encounter_id\
                                  WHERE patient.voided = 0 AND o.voided = 0
                                  AND patient.patient_id IN (#{ids})
                                  #{categorise}
                                  AND patient.patient_id NOT IN (SELECT person_id FROM obs  WHERE concept_id = #{ht_concept}
                                  AND value_coded != (SELECT concept_id FROM concept_name WHERE name = 'Normal'))
                                  
                                 GROUP BY patient.patient_id").length #rescue 0
    elsif type.upcase == "ASTHMA"
      @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders
                                  INNER JOIN person p ON p.person_id = orders.patient_id
                                  INNER JOIN patient ON patient.patient_id = orders.patient_id \
                                  WHERE patient.voided = 0 AND patient.patient_id IN (#{ids}) 
                                  #{categorise} AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
                                  concept_set = #{@asthma_id})
                                  GROUP BY patient_id").length rescue 0
    elsif type.upcase == "EPILEPSY"
      @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders
                                  INNER JOIN person p ON p.person_id = orders.patient_id
                                  INNER JOIN patient ON patient.patient_id = orders.patient_id \
                                  WHERE patient.voided = 0 AND patient.patient_id IN (#{ids}) 
                                  #{categorise} AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
                                  concept_set = #{@epilepsy_id})
                                  GROUP BY patient_id").length rescue 0
    elsif type.upcase == "DM HT"
      ht_concept = ConceptName.find_by_name("cardiovascular system diagnosis").concept_id
      dm_concept = ConceptName.find_by_name("Patient has Diabetes").concept_id
      @orders = Order.find_by_sql("SELECT o.person_id FROM obs o
                                  INNER JOIN person p ON p.person_id = o.person_id
                                  INNER JOIN patient ON patient.patient_id = o.person_id
                                  INNER JOIN orders ON orders.patient_id = patient.patient_id
                                  WHERE patient.voided = 0 AND o.voided = 0 AND orders.voided = 0 AND patient.patient_id IN (#{ids}) \
                                   #{categorise} AND (o.concept_id = #{dm_concept}
                                  AND o.value_coded != (SELECT concept_id FROM concept_name WHERE name = 'Normal'))
                                  AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
                                  concept_set = #{@diabetes_id})
                                  GROUP BY patient.patient_id").length
      
    elsif type.upcase == "OTHER"
      @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders
                                  INNER JOIN person p ON p.person_id = orders.patient_id
                                  INNER JOIN patient ON patient.patient_id = orders.patient_id \
                                  WHERE patient.voided = 0 AND patient.patient_id IN (#{ids}) AND \
                                  #{categorise} AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
                                  concept_set NOT IN (#{@hypertensition_medication_id}, #{@asthma_id},#{@diabetes_id}, #{@epilepsy_id})) \
                                  GROUP BY patient_id").length rescue 0
      
    end 
    return @orders
  end

  def total_children_registered(ids, sex=nil, age=nil )
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(person.gender) = '#{sex.upcase}'
                                    OR UCASE(person.gender) = '#{patient_initial}')"
    end
    if ! age.blank?
      if age == 14
        range = "AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) > 14
                AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 54"
      elsif age == 54
        range = "AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) > 54"
      else
        range = "AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14"
      end
    end
    unless ids.blank?
      conditions = "AND patient.patient_id IN (#{ids})"
    end
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["patient.date_created >= ?
								 										AND patient.date_created <= ? 
                                     #{conditions} #{categorise} #{range}
																		AND patient.voided = 0", @start_date, @end_date]
    )
  end

  def total_men_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["DATE(patient.date_created) >= ? AND
																		DATE(patient.date_created) <= ?
																		AND (UCASE(person.gender) = ?
                                    OR UCASE(person.gender) = ?)
                                    AND patient.patient_id IN (#{ids})
																		AND patient.voided = 0",
        @start_date, @end_date, "M", "MALE"]
    )
  end

  def alcohol(ids, sex)
    @orders = Order.find_by_sql("SELECT DISTINCT obs.person_id FROM obs
                                  INNER JOIN person on person .person_id = obs.person_id
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'DOES THE PATIENT DRINK ALCOHOL?')
                                      AND value_coded = (SELECT concept_id FROM concept_name WHERE name = 'YES') AND
                                       DATE(patient.date_created) >= '#{@start_date}' AND DATE(patient.date_created) <= '#{@end_date}' \
                                        AND patient.voided = 0
                                      AND patient.patient_id IN (#{ids})
                                      AND person.gender LIKE '#{sex}%'
                                      AND obs.voided = 0").length rescue 0
  end

  def alcohol_ever(ids, sex)
    @orders = Order.find_by_sql("SELECT DISTINCT obs.person_id FROM obs
                                  INNER JOIN person on person .person_id = obs.person_id
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'DOES THE PATIENT DRINK ALCOHOL?')
                                      AND value_coded = (SELECT concept_id FROM concept_name WHERE name = 'YES') AND
                                      DATE(patient.date_created) <= '#{@end_date}' \
                                        AND patient.voided = 0
                                      AND patient.patient_id IN (#{ids})
                                      AND person.gender LIKE '#{sex}%'
                                      AND obs.voided = 0").length rescue 0
  end

  def smoking(ids, sex)
    @orders = Order.find_by_sql("SELECT DISTINCT obs.person_id FROM obs
                                  INNER JOIN person on person .person_id = obs.person_id
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'CURRENT SMOKER')
                                      AND value_coded = (SELECT concept_id FROM concept_name WHERE name = 'YES') AND
                                       DATE(patient.date_created) >= '#{@start_date}' AND DATE(patient.date_created) <= '#{@end_date}' \
                                        AND patient.voided = 0
                                      AND patient.patient_id IN (#{ids})
                                      AND person.gender LIKE '#{sex}%'
                                      AND obs.voided = 0").length rescue 0
  end

  def smoking_ever(ids, sex)
    @orders = Order.find_by_sql("SELECT DISTINCT obs.person_id FROM obs
                                  INNER JOIN person on person .person_id = obs.person_id
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'CURRENT SMOKER')
                                      AND value_coded = (SELECT concept_id FROM concept_name WHERE name = 'YES') AND
                                      DATE(patient.date_created) <= '#{@end_date}' \
                                        AND patient.voided = 0
                                      AND patient.patient_id IN (#{ids})
                                      AND person.gender LIKE '#{sex}%'
                                      AND obs.voided = 0").length rescue 0
  end

  def bmi(ids, sex)
    @orders = Order.find_by_sql("SELECT DISTINCT obs.person_id FROM obs
                                  INNER JOIN person on person .person_id = obs.person_id
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'BODY MASS INDEX, MEASURED')
                                      AND (value_numeric >= 30 OR value_text >= 30 ) AND
                                       DATE(patient.date_created) >= '#{@start_date}' AND DATE(patient.date_created) <= '#{@end_date}' \
                                        AND patient.voided = 0
                                      AND patient.patient_id IN (#{ids})
                                      AND person.gender LIKE '#{sex}%'
                                      AND obs.voided = 0").length rescue 0
  end

  def bmi_ever(ids, sex)
    @orders = Order.find_by_sql("SELECT DISTINCT obs.person_id FROM obs
                                  INNER JOIN person on person .person_id = obs.person_id
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'BODY MASS INDEX, MEASURED')
                                      AND (value_numeric >= 30 OR value_text >= 30 ) AND
                                      DATE(patient.date_created) <= '#{@end_date}' \
                                        AND patient.voided = 0
                                      AND patient.patient_id IN (#{ids})
                                      AND person.gender LIKE '#{sex}%'
                                      AND obs.voided = 0").length rescue 0
  end


  def total_adult_men_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["patient.date_created >= ?
																		AND patient.date_created <= ?
																		AND (UCASE(person.gender) = ?
                                    OR UCASE(person.gender) = ?)
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
                                    AND patient.patient_id IN (#{ids})
																		AND patient.voided = 0",
        @start_date, @end_date, "M", "MALE"]
    )
  end

  def total_boy_children_registered(ids)
		Patient.find(:all,
      :include => {:person =>{}},
      :conditions => ["patient.date_created >= ?
								 									AND patient.date_created <= ?
																	AND (UCASE(person.gender) = ?
                                  OR UCASE(person.gender) = ?)
																	AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
                                  AND patient.patient_id IN (#{ids})
																	AND patient.voided = 0",
        @start_date, @end_date, "M", "MALE"]
    )
  end

  def total_women_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["patient.date_created >= ? AND
																		patient.date_created <= ?
																		AND (UCASE(person.gender) = ?
                                    OR UCASE(person.gender) = ?)
                                    AND patient.patient_id IN (#{ids})
																		AND patient.voided = 0",
        @start_date, @end_date, "F", "FEMALE"]
    )
  end

  def total_adult_women_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["patient.date_created >= ?
																		AND patient.date_created <= ?
																		AND (UCASE(person.gender) = ?
                                    OR UCASE(person.gender) = ?)
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
                                    AND patient.patient_id IN (#{ids})
																		AND patient.voided = 0",
        @start_date, @end_date, "F", "FEMALE"]
    )
  end

  def total_girl_children_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["patient.date_created >= ?
								 									AND patient.date_created <= ?
																	AND (UCASE(person.gender) = ?
                                  OR UCASE(person.gender) = ?)
																	AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
                                  AND patient.patient_id IN (#{ids})
																	AND patient.voided = 0",
        @start_date, @end_date, "F", "FEMALE"]
    )
  end

  # Get all patients ever registered
  def total_ever_registered(encounter_type=nil)
    
    Patient.find_by_sql("
                          SELECT DISTINCT p.patient_id FROM patient p
                          WHERE p.voided = 0
                          AND p.date_created <= '#{@end_date}'")
  end

  def total_adults_ever_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
								 									AND patient.voided = 0 
                                  AND patient.patient_id IN (#{ids})
                                  AND patient.date_created <= ?",
        @end_date]
    )
  end

  def total_children_ever_registered(ids, sex=nil, age=nil)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(person.gender) = '#{sex.upcase}'
                                    OR UCASE(person.gender) = '#{patient_initial}')"
    end
    if ! age.blank?
      if age == 14
        range = "AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) > 14
                AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 54"
      elsif age == 54
        range = "AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) > 54"
      else
        range = "AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14"
      end
    end
    unless ids.blank?
      conditions = "AND patient.patient_id IN (#{ids})"
    end
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["patient.voided = 0 #{conditions} #{categorise} #{range}
                                    AND patient.date_created <= ?",
        @end_date]
    )
  end

  def total_men_ever_registered(ids)
    Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["(person.gender = 'M'
                                    OR UCASE(person.gender) = 'MALE')
    																AND patient.voided = 0
                                    AND patient.patient_id IN (#{ids})
    																AND patient.date_created <= ?",
        @end_date])
  end

  def total_adult_men_ever_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["(person.gender = 'M'
                                    OR UCASE(person.gender) = 'MALE')
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
																		AND patient.voided = 0  AND patient.patient_id IN (#{ids})
																		AND patient.date_created <= ?", @end_date])
  end

  def total_boy_children_ever_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["(person.gender = ?
                                   OR UCASE(person.gender) = ?)
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
																		AND patient.voided = 0  AND patient.patient_id IN (#{ids})
																		AND patient.date_created <= ?", "M", "MALE", @end_date])
  end

  def total_women_ever_registered(ids)
    Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["(person.gender = ?
                                    OR UCASE(person.gender) = ?)
    																AND patient.voided = 0  AND patient.patient_id IN (#{ids})
    																AND patient.date_created <= ?",
        "F", "FEMALE", @end_date])
  end

  def total_adult_women_ever_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["(person.gender = ?
                                    OR UCASE(person.gender) = ?)
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) >= 15
																		AND patient.voided = 0  AND patient.patient_id IN (#{ids})
																		AND patient.date_created <= ?", "F", "FEMALE", @end_date])
  end

  def total_girl_children_ever_registered(ids)
		Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["(person.gender = ?
                                    OR UCASE(person.gender) = ?)
																		AND COALESCE(DATEDIFF(NOW(), person.birthdate)/365, 0) <= 14
																		AND patient.voided = 0 AND patient.patient_id IN (#{ids})
																		AND patient.date_created <= ?", "F", "FEMALE", @end_date])
  end

  # Oral Treatments
  def oral_treatments_ever												 
    (@ids_for_patients_on_metformin_and_glibenclamide_ever - @ids_for_patients_on_insulin_ever).uniq.size
  end

  def oral_treatments
    (@ids_for_patients_on_metformin_and_glibenclamide - @ids_for_patients_on_insulin).size
  end

  def diet_only(ids, cumulative=nil)
    if cumulative.blank?
      oral = @ids_for_patients_on_metformin_and_glibenclamide -@ids_for_patients_on_insulin
      insulin = @ids_for_patients_on_insulin - @ids_for_patients_on_metformin_and_glibenclamide
      oral_insulin = @ids_for_patients_on_insulin & @ids_for_patients_on_metformin_and_glibenclamide
    else
      oral = @ids_for_patients_on_metformin_and_glibenclamide_ever -@ids_for_patients_on_insulin_ever
      insulin = @ids_for_patients_on_insulin_ever - @ids_for_patients_on_metformin_and_glibenclamide_ever
      oral_insulin = @ids_for_patients_on_insulin_ever & @ids_for_patients_on_metformin_and_glibenclamide_ever
    end
    total = (oral + insulin + oral_insulin).uniq.join(",")
    Patient.count(:all,
      :include => {:person =>{}},
      :conditions => ["patient.voided = 0
                                  AND patient.patient_id IN (#{ids})
                                  AND patient.patient_id NOT IN (#{total})"]
    )
  end
  # Insulin
  def insulin_ever                                        
    (@ids_for_patients_on_insulin_ever - @ids_for_patients_on_metformin_and_glibenclamide_ever).size
  end

  def insulin
    (@ids_for_patients_on_insulin - @ids_for_patients_on_metformin_and_glibenclamide).size
  end

  # Oral and Insulin
  def oral_and_insulin_ever
    (@ids_for_patients_on_insulin_ever & @ids_for_patients_on_metformin_and_glibenclamide_ever).size
  end

  def oral_and_insulin
    (@ids_for_patients_on_insulin & @ids_for_patients_on_metformin_and_glibenclamide).size
  end

  # Metformin
  def metformin_ever
    @ids_for_patients_on_metformin_ever.size
  end

  def metformin
    @ids_for_patients_on_metformin.size
  end

  # Glibenclamide
  def glibenclamide_ever
		@ids_for_patients_on_glibenclamide_ever.size
  end

  def glibenclamide
		@ids_for_patients_on_glibenclamide.size
  end

  # Lente Insulin
  def lente_insulin_ever
    @ids_for_patients_on_lente_insulin_ever.size
  end

  def lente_insulin
		@ids_for_patients_on_lente_insulin.size
  end

  # Soluble Insulin
  def soluble_insulin_ever
  	@ids_for_patients_on_soluble_insulin_ever.size
  end

  def soluble_insulin
  	@ids_for_patients_on_soluble_insulin.size
  end

  # Background Retinopathy
  def background_retinapathy_ever
		@complications_hash_upto_end_date['Background retinopathy'].to_i
  end

  def background_retinapathy
		@complications_hash_btn_dates['Background retinopathy'].to_i
  end

  # Ploriferative Retinopathy
  def ploriferative_retinapathy_ever
		@complications_hash_upto_end_date['Ploriferative retinopathy'].to_i
  end

  def ploriferative_retinapathy
		@complications_hash_btn_dates['Ploriferative retinopathy'].to_i
  end

  # End Stage Retinopathy
  def end_stage_retinapathy_ever
		@complications_hash_upto_end_date['End stage disease'].to_i
  end

  def end_stage_retinapathy
		@complications_hash_btn_dates['End stage disease'].to_i
  end

  # Cataract
  def cataracts_ever
		@complications_hash_upto_end_date['Cataract'].to_i
  end

  def cataracts
		@complications_hash_btn_dates['Cataract'].to_i
  end

  # Cataract
  def macrovascular_ever
		@complications_hash_upto_end_date['Myocardial infarction'].to_i +
      @complications_hash_upto_end_date['Angina'].to_i +
      @complications_hash_upto_end_date['Peripheral vascular disease'].to_i +
      @complications_hash_upto_end_date['Stroke'].to_i
  end

  def macrovascular
		@complications_hash_btn_dates['Myocardial infarction'].to_i +
      @complications_hash_btn_dates['Angina'].to_i +
      @complications_hash_btn_dates['Peripheral vascular disease'].to_i +
      @complications_hash_btn_dates['Stroke'].to_i
  end

  # No complications
  def no_complications_ever(ids)

    heart_failure_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE ( concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Cardiac') OR UCASE(value_text) = 'CARDIAC') \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    mi_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Myocardial injactia(MI)') OR value_text = 'Myocardial injactia(MI)') \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    stroke_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'stroke' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'stroke') \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    tia_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'TIA' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'TIA') \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    ulcers_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Foot ulcers' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Foot ulcers') \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    impotence_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Impotence' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Impotence') \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    amputation_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Amputation' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Amputation') \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    kidney_failure_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Creatinine' and concept_name_type IS NULL) OR UCASE(value_text) = 'CREATININE') \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")
   
    bgretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'BACKGROUND RETINOPATHY')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    plretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'PLORIFERATIVE RETINOPATHY')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    esretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'END STAGE DISEASE')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    cataract = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CATARACT')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    pvd = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MYOCARDIAL INFARCTION' OR name = 'ANGINA' \
                                      OR name = 'STROKE' OR name = 'PERIPHERAL VASCULAR DISEASE')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    maculopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MACULOPATHY') OR UCASE(value_text) = 'MACULOPATHY'").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    numbness = Order.find_by_sql("SELECT DISTINCT person_id FROM obs WHERE value_coded = \
                                      (SELECT concept_id FROM concept_name where name = 'NUMBNESS SYMPTOMS') \
                                        AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    amputation = Order.find_by_sql("SELECT DISTINCT person_id FROM obs WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'AMPUTATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    ulcers = Order.find_by_sql("SELECT DISTINCT person_id FROM obs WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'CURRENT FOOT ULCERATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                      ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    creatinine = Order.find_by_sql("SELECT DISTINCT person_id, value_numeric FROM obs \
                                    WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CREATININE') AND COALESCE(value_numeric, 0) >= 1.2").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    urine = Order.find_by_sql("SELECT DISTINCT person_id FROM obs WHERE concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'URINE PROTEIN') \
                                          AND value_coded IN (SELECT concept_id FROM concept_name
                                          WHERE name IN ('+', '++', '+++', '++++', 'trace') AND locale = 'en')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    @orders = Order.find_by_sql("SELECT DISTINCT patient_id FROM patient WHERE NOT patient_id IN \
                                (" + (bgretinopathy.length > 0 ? bgretinopathy : "0") +  ") AND NOT patient_id IN (" +
        (plretinopathy.length > 0 ? plretinopathy : "0") + ")  AND NOT patient_id IN (" +
        (esretinopathy.length > 0 ? esretinopathy : "0") + ") AND NOT patient_id IN (" +
        (cataract.length > 0 ? cataract : "0") + ") AND NOT patient_id IN (" +
        (pvd.length > 0 ? pvd : "0") + ") AND NOT patient_id IN (" +
        (maculopathy.length > 0 ? maculopathy : "0") + ") AND NOT patient_id IN (" +
        (numbness.length > 0 ? numbness : "0") + ") AND NOT patient_id IN (" +
        (amputation.length > 0 ? amputation : "0") + ") AND NOT patient_id IN (" +
        (ulcers.length > 0 ? ulcers : "0") + ") AND NOT patient_id IN (" +
        (creatinine.length > 0 ? creatinine : "0") + ") AND NOT patient_id IN (" +
        (kidney_failure_ever.length > 0 ? kidney_failure_ever : "0") + ") AND NOT patient_id IN (" +
        (ulcers_ever.length > 0 ? ulcers_ever : "0") + ") AND NOT patient_id IN (" +
        (heart_failure_ever.length > 0 ? heart_failure_ever : "0") + ") AND NOT patient_id IN (" +
        (amputation_ever.length > 0 ? amputation_ever : "0") + ") AND NOT patient_id IN (" +
        (impotence_ever.length > 0 ? impotence_ever : "0") + ") AND NOT patient_id IN (" +
        (tia_ever.length > 0 ? tia_ever : "0") + ") AND NOT patient_id IN (" +
        (stroke_ever.length > 0 ? stroke_ever : "0") + ") AND NOT patient_id IN (" +
        (mi_ever.length > 0 ? mi_ever : "0") + ") AND NOT patient_id IN (" +
        (urine.length > 0 ? urine : "0") + ") AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                         AND patient.patient_id IN (#{ids}) AND patient.voided = 0").length
  end

  def no_complications(ids)

    heart_failure_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Cardiac') OR UCASE(value_text) = 'CARDIAC') \
                                    AND patient.voided = 0 \
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    mi_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Myocardial injactia(MI)') OR value_text = 'Myocardial injactia(MI)') \
                                    AND patient.voided = 0  \
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    stroke_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'stroke' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'stroke') \
                                    AND patient.voided = 0  \
                                     AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    tia_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'TIA' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'TIA') \
                                    AND patient.voided = 0  \
                                     AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    ulcers_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Foot ulcers' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Foot ulcers') \
                                    AND patient.voided = 0  \
                                        AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    impotence_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Impotence' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Impotence') \
                                    AND patient.voided = 0  \
                                       AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    amputation_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Amputation' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Amputation') \
                                    AND patient.voided = 0  \
                                       AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")


    kidney_failure_ever = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Creatinine' and concept_name_type IS NULL) OR UCASE(value_text) = 'CREATININE') \
                                    AND patient.voided = 0  \
                                       AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")



    bgretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'BACKGROUND RETINOPATHY')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    plretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'PLORIFERATIVE RETINOPATHY')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    esretinopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'END STAGE DISEASE')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    cataract = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CATARACT')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    pvd = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MYOCARDIAL INFARCTION' OR name = 'ANGINA' \
                                      OR name = 'STROKE' OR name = 'PERIPHERAL VASCULAR DISEASE')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    maculopathy = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MACULOPATHY') OR UCASE(value_text) = 'MACULOPATHY')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    numbness = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                      (SELECT concept_id FROM concept_name where name = 'NUMBNESS SYMPTOMS') \
                                        AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    amputation = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'AMPUTATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    ulcers = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'CURRENT FOOT ULCERATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                      ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG'))
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    creatinine = Order.find_by_sql("SELECT DISTINCT person_id, value_numeric FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CREATININE') AND COALESCE(value_numeric, 0) >= 1.2
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    urine = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'URINE PROTEIN') \
                                          AND value_coded IN (SELECT concept_id FROM concept_name
                                          WHERE name IN ('+', '++', '+++', '++++', 'trace') AND locale = 'en')
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")

    @orders = Order.find_by_sql("SELECT DISTINCT patient_id FROM patient WHERE NOT patient_id IN \
                                (" + (bgretinopathy.length > 0 ? bgretinopathy : "0") +  ") AND NOT patient_id IN (" +
        (plretinopathy.length > 0 ? plretinopathy : "0") + ")  AND NOT patient_id IN (" +
        (esretinopathy.length > 0 ? esretinopathy : "0") + ") AND NOT patient_id IN (" +
        (cataract.length > 0 ? cataract : "0") + ") AND NOT patient_id IN (" +
        (pvd.length > 0 ? pvd : "0") + ") AND NOT patient_id IN (" +
        (maculopathy.length > 0 ? maculopathy : "0") + ") AND NOT patient_id IN (" +
        (numbness.length > 0 ? numbness : "0") + ") AND NOT patient_id IN (" +
        (amputation.length > 0 ? amputation : "0") + ") AND NOT patient_id IN (" +
        (ulcers.length > 0 ? ulcers : "0") + ") AND NOT patient_id IN (" +
        (creatinine.length > 0 ? creatinine : "0") + ") AND NOT patient_id IN (" +
        (kidney_failure_ever.length > 0 ? kidney_failure_ever : "0") + ") AND NOT patient_id IN (" +
        (ulcers_ever.length > 0 ? ulcers_ever : "0") + ") AND NOT patient_id IN (" +
        (heart_failure_ever.length > 0 ? heart_failure_ever : "0") + ") AND NOT patient_id IN (" +
        (amputation_ever.length > 0 ? amputation_ever : "0") + ") AND NOT patient_id IN (" +
        (impotence_ever.length > 0 ? impotence_ever : "0") + ") AND NOT patient_id IN (" +
        (tia_ever.length > 0 ? tia_ever : "0") + ") AND NOT patient_id IN (" +
        (stroke_ever.length > 0 ? stroke_ever : "0") + ") AND NOT patient_id IN (" +
        (mi_ever.length > 0 ? mi_ever : "0") + ") AND NOT patient_id IN (" +
        (urine.length > 0 ? urine : "0") + ")
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                     AND patient.patient_id IN (#{ids}) AND patient.voided = 0").length
  end

  # Nephropathy: Urine Protein
  def urine_protein_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                      WHERE concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'URINE PROTEIN') \
                                          AND value_coded IN (SELECT concept_id FROM concept_name
                                          WHERE name IN ('+', '++', '+++', '++++', 'trace') AND locale = 'en') AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def urine_protein
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                       WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'URINE PROTEIN') \
                                          AND value_coded IN (SELECT concept_id FROM concept_name
                                          WHERE name IN ('+', '++', '+++', '++++', 'trace') AND locale = 'en')\
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # Nephropathy: Raised Creatinine >= 1.2mg/dl
  def creatinine_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id, value_numeric FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CREATININE') AND COALESCE(value_numeric, 0) >= 1.2 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0").length
  end

  def creatinine
    @orders = Order.find_by_sql("SELECT DISTINCT person_id, value_numeric FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                      WHERE name = 'CREATININE') AND COALESCE(value_numeric, 0) >= 1.2 \
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0").length
  end

  # Neuropathy: Numbness Symptoms
  def numbness_symptoms_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE value_coded = \
                                      (SELECT concept_id FROM concept_name where name = 'NUMBNESS SYMPTOMS') \
                                        AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                         AND patient.patient_id IN (#{ids}) AND patient.voided = 0").length
  end

  def numbness_symptoms(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                      (SELECT concept_id FROM concept_name where name = 'NUMBNESS SYMPTOMS') \
                                        AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                        ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) \
                                    AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                     AND patient.patient_id IN (#{ids}) AND patient.voided = 0").length
  end

  # Neuropathy: Current Foot Ulceration
  def current_foot_ulceration_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'CURRENT FOOT ULCERATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                      ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                         AND patient.patient_id IN (#{ids}) AND patient.voided = 0").length
  end

  def current_foot_ulceration(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name where name = 'CURRENT FOOT ULCERATION') \
                                      AND concept_id IN (SELECT concept_id FROM concept_name where name IN \
                                      ('LEFT FOOT/LEG', 'RIGHT FOOT/LEG')) \
                                      AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                     AND patient.patient_id IN (#{ids}) AND patient.voided = 0").length
  end

  # TB After Diabetes
  def tb_after_diabetes_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM \
                                    (SELECT person_id, value_datetime FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                      WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                        WHERE name = 'DIABETES DIAGNOSIS DATE') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v1,
                                    (SELECT person_id, value_datetime FROM obs o  \
                                      LEFT OUTER JOIN patient ON patient.patient_id = o.person_id \
                                      WHERE concept_id = (SELECT concept_id FROM concept_name WHERE \
                                       name = 'DIAGNOSIS DATE') AND obs_group_id IN (SELECT obs_id FROM obs s WHERE \
                                        concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')) \
                                      AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v2
                                      WHERE v1.person_id = v2.person_id AND v1.value_datetime <= v2.value_datetime").length
  end

  def tb_after_diabetes(ids)
    @orders = Order.find_by_sql("SELECT v1.person_id FROM \
                                    (SELECT * FROM obs WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                        WHERE name = 'DIABETES DIAGNOSIS DATE')) AS v1, \
                                    (SELECT * FROM obs o WHERE concept_id = (SELECT concept_id FROM concept_name WHERE \
                                       name = 'DIAGNOSIS DATE') AND obs_group_id IN (SELECT obs_id FROM obs s WHERE \
                                        concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?'))) AS v2, \
                                    patient WHERE v1.person_id = v2.person_id AND v1.value_datetime <= v2.value_datetime \
                                      AND patient.patient_id = v1.person_id  AND patient.patient_id IN (#{ids}) AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  # TB After Diabetes
  def tb_before_diabetes_ever(ids)
    #raise ids.to_yaml
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM \
                                    (SELECT person_id, value_datetime FROM obs \
                                      LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                      WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                        WHERE name = 'DIABETES DIAGNOSIS DATE') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v1,
                                    (SELECT person_id, value_datetime FROM obs o  \
                                      LEFT OUTER JOIN patient ON patient.patient_id = o.person_id \
                                      WHERE concept_id = (SELECT concept_id FROM concept_name WHERE \
                                       name = 'DIAGNOSIS DATE') AND obs_group_id IN (SELECT obs_id FROM obs s WHERE \
                                        concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')) \
                                      AND patient.voided = 0 AND patient.patient_id IN (#{ids}) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v2
                                      WHERE v1.person_id = v2.person_id AND v1.value_datetime > v2.value_datetime").length
  end

  def tb_before_diabetes(ids)
    @orders = Order.find_by_sql("SELECT v1.person_id FROM \
                                    (SELECT * FROM obs WHERE concept_id IN (SELECT concept_id FROM concept_name \
                                        WHERE name = 'DIABETES DIAGNOSIS DATE')) AS v1, \
                                    (SELECT * FROM obs o WHERE concept_id = (SELECT concept_id FROM concept_name WHERE \
                                       name = 'DIAGNOSIS DATE') AND obs_group_id IN (SELECT obs_id FROM obs s WHERE \
                                        concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?'))) AS v2, \
                                    patient WHERE v1.person_id = v2.person_id AND v1.value_datetime > v2.value_datetime \
                                      AND patient.patient_id = v1.person_id  AND patient.patient_id IN (#{ids}) AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length
  end

  def no_tb_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?') AND value_coded IN \
                              (SELECT concept_id FROM concept_name WHERE name = 'NO') AND patient.voided = 0 AND patient.patient_id IN (#{ids}) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' ").length
  end

  def no_tb(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?') AND value_coded IN \
                              (SELECT concept_id FROM concept_name WHERE name = 'NO') AND \
                               DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                        AND patient.voided = 0  AND patient.patient_id IN (#{ids})").length
  end

  def tb_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?') AND value_coded IN \
                              (SELECT concept_id FROM concept_name WHERE name = 'YES') AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' AND obs.voided = 0").length
  end

  def tb(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id 
                                 FROM obs LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id
                                 WHERE concept_id = (SELECT concept_id \
                                                     FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')
                                AND value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'YES')
                                AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date + "'
                                AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'
                                AND patient.voided = 0  AND patient.patient_id IN (#{ids})
                                AND obs.voided = 0").length
  end

  def tb_known_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id 
                                 FROM obs LEFT OUTER JOIN patient ON  patient.patient_id = obs.person_id
                                 WHERE concept_id = (SELECT concept_id
                                                      FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')
                                 AND patient.voided = 0 AND patient.patient_id IN (#{ids})
                                 AND obs.voided = 0
                                 AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' ").length rescue 0
  end

  def tb_known(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id 
                              WHERE concept_id = (SELECT concept_id FROM concept_name
                                                  WHERE name = 'HAVE YOU EVER HAD TB?')
                              AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +"'
                              AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'
                              AND patient.voided = 0 AND patient.patient_id IN (#{ids})
                              AND obs.voided = 0 ").length rescue 0
  end

  def tb_unkown_ever(ids)
    
    tb = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON \
                              patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id \
                              FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')").collect{|o| o.person_id}.compact.delete_if{|x| x == ""}.join(", ")
    
    @orders = Order.find_by_sql("SELECT DISTINCT patient_id FROM patient WHERE NOT patient_id IN \
                                (" + (tb.length > 0 ? tb : "0") +  ") AND patient.voided = 0 AND patient.patient_id IN (#{ids}) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length rescue 0
  end

  def tb_unkown(ids)

    tb = Order.find_by_sql("SELECT DISTINCT patient_id FROM patient
                        WHERE patient_id NOT IN (
                        SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON
                        patient.patient_id = obs.person_id WHERE concept_id = (SELECT concept_id
                        FROM concept_name WHERE name = 'HAVE YOU EVER HAD TB?')
                        AND obs.voided = 0
                        AND patient.voided = 0
                        AND DATE(patient.date_created) >= '#{@start_date}' AND DATE(patient.date_created) <= '#{@end_date}')
                        AND patient.voided = 0
                        AND patient.patient_id IN (#{ids})
                        AND DATE(patient.date_created) >= '#{@start_date}' AND DATE(patient.date_created) <= '#{@end_date}'").length rescue 0
  end

  # HIV Status: Reactive Not on ART
  def reactive_not_on_art_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM
                                      (SELECT person_id FROM obs LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE concept_id = (SELECT concept_id FROM concept_name \
                                          WHERE name = 'ON ART') AND value_coded IN (SELECT concept_id FROM concept_name \
                                            WHERE name = 'NO') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v1,
                                      (SELECT person_id FROM obs  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE value_coded = (SELECT concept_id FROM concept_name \
                                        WHERE name = 'POSITIVE') AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v2 WHERE v1.person_id = v2.person_id").length rescue 0
  end

  def reactive_not_on_art(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM
                                      (SELECT * FROM obs WHERE concept_id = (SELECT concept_id FROM concept_name \
                                          WHERE name = 'ON ART') AND value_coded IN (SELECT concept_id FROM concept_name \
                                            WHERE name = 'NO')) AS v1,
                                      (SELECT * FROM obs WHERE value_coded = (SELECT concept_id FROM concept_name \
                                        WHERE name = 'POSITIVE')) AS v2, \
                                    patient WHERE v1.person_id = v2.person_id \
                                      AND patient.patient_id = v1.person_id AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'  AND patient.patient_id IN (#{ids})").length rescue 0
  end

  # HIV Status: Reactive  on ART
  def reactive_on_art_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM
                                      (SELECT person_id FROM obs  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE concept_id = (SELECT concept_id FROM concept_name \
                                          WHERE name = 'ON ART') AND value_coded IN (SELECT concept_id FROM concept_name \
                                            WHERE name = 'YES') AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v1,
                                      (SELECT person_id FROM obs  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE value_coded = (SELECT concept_id FROM concept_name \
                                        WHERE name = 'POSITIVE') AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "') AS v2 WHERE v1.person_id = v2.person_id").length rescue 0
  end

  def reactive_on_art(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT v1.person_id FROM
                                      (SELECT * FROM obs WHERE concept_id = (SELECT concept_id FROM concept_name \
                                          WHERE name = 'ON ART') AND value_coded IN (SELECT concept_id FROM concept_name \
                                            WHERE name = 'YES')) AS v1,
                                      (SELECT * FROM obs WHERE value_coded = (SELECT concept_id FROM concept_name \
                                        WHERE name = 'POSITIVE')) AS v2, \
                                    patient WHERE v1.person_id = v2.person_id \
                                      AND patient.patient_id = v1.person_id AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' AND patient.patient_id IN (#{ids})").length rescue 0
  end

  # HIV Status: Non Reactive
  def non_reactive_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name WHERE name = 'NEGATIVE') and concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'HIV STATUS') AND \
                                        DATEDIFF(NOW(), obs_datetime)/365 < 1 AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' AND patient.patient_id IN (#{ids})").length rescue 0
  end

  def non_reactive(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs  \
                                    LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE value_coded = (SELECT concept_id FROM concept_name WHERE name = 'NEGATIVE') AND \
                                    concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV STATUS') AND \
                                        DATEDIFF(NOW(), obs_datetime)/365 < 1 \
                                      AND patient.patient_id = obs.person_id AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0 AND patient.patient_id IN (#{ids})").length rescue 0
  end

  # HIV Status: Unknown
  def unknown_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                        WHERE value_coded = \
                                    (SELECT concept_id FROM concept_name WHERE name = 'NEGATIVE') and concept_id = \
                                      (SELECT concept_id FROM concept_name WHERE name = 'HIV STATUS') AND \
                                        DATEDIFF(NOW(), obs_datetime)/365 > 1 AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' AND patient.patient_id IN (#{ids})").length rescue 0
  end

  def unknown(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs  \
                                    LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                    WHERE value_coded = (SELECT concept_id FROM concept_name WHERE name = 'NEGATIVE') AND \
                                    concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV STATUS') \
                                      AND patient.patient_id = obs.person_id AND DATEDIFF(NOW(), obs_datetime)/365 > 1 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids})").length rescue 0
  end

  # Outcome
  def discharged_ever(ids, sex=nil)
    program_id = Program.find_by_name("CHRONIC CARE PROGRAM").id
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end

    @dead = PatientState.find_by_sql("SELECT DISTINCT p.patient_id FROM patient p
                INNER JOIN  patient_program pp on pp.patient_id = p.patient_id #{joined}
                inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{program_id}, '#{@end_date}')
                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                WHERE ps.start_date <= '#{@end_date}'
                #{categorise} AND c.name = 'DISCHARGED'
                 AND p.patient_id IN (#{ids})").length rescue 0
  end

  def discharged(ids, sex=nil)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end
    program_id = Program.find_by_name("CHRONIC CARE PROGRAM").id

    @dead = PatientState.find_by_sql("SELECT DISTINCT p.patient_id FROM patient p
                INNER JOIN  patient_program pp on pp.patient_id = p.patient_id #{joined}
                inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{program_id}, '#{@end_date}')
                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                WHERE ps.start_date <= '#{@end_date}'
                #{categorise} AND ps.start_date >= '#{@start_date}'
                AND c.name = 'DISCHARGED'
                 AND p.patient_id IN (#{ids})").length rescue 0
  end

  def dead_ever(ids, sex=nil)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end
    @dead = PatientState.find_by_sql("SELECT DISTINCT p.patient_id FROM patient p
                INNER JOIN  patient_program pp on pp.patient_id = p.patient_id #{joined}
                inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{@program_id}, '#{@end_date}')
                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                WHERE ps.start_date <= '#{@end_date}'
                #{categorise} AND c.name = 'PATIENT DIED'
                AND p.patient_id IN (#{ids})").length rescue 0
  end

  def dead(ids, sex=nil)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end
    @dead = PatientState.find_by_sql("SELECT DISTINCT p.patient_id FROM patient p
                INNER JOIN  patient_program pp on pp.patient_id = p.patient_id #{joined}
                inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{@program_id}, '#{@end_date}')
                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                WHERE ps.start_date <= '#{@end_date}'
                AND ps.start_date >= '#{@start_date}'
               #{categorise} AND c.name = 'PATIENT DIED'
                AND p.patient_id IN (#{ids})").length rescue 0

  end

  def alive_ever(ids, sex=nil)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end
  	Person.find(:all, :conditions => ["person_id IN (SELECT patient_id FROM patient WHERE patient.patient_id IN (#{ids})) AND dead = 0 AND DATE(date_created) <= DATE('#{@end_date}')"]).length
  end

  def alive(ids, sex=nil)

    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end
  	Person.find(:all,
      :conditions => ["person_id IN (SELECT patient_id FROM patient WHERE patient.patient_id IN (#{ids})) AND dead = 0 AND DATE(date_created) >= DATE('#{@start_date}') AND DATE(date_created) <= DATE('#{@end_date}')"]).length
  end

  def transfer_out_ever(ids, sex=nil)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end
    @dead = PatientState.find_by_sql("SELECT DISTINCT p.patient_id FROM patient p
                INNER JOIN  patient_program pp on pp.patient_id = p.patient_id #{joined}
                inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{@program_id}, '#{@end_date}')
                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                WHERE ps.start_date <= '#{@end_date}'
                #{categorise} AND p.patient_id IN (#{ids})
                AND c.name = 'PATIENT TRANSFERRED OUT'").length rescue 0

  end

  def transfer_out(ids, sex=nil)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end
    @dead = PatientState.find_by_sql("SELECT DISTINCT p.patient_id FROM patient p
                INNER JOIN  patient_program pp on pp.patient_id = p.patient_id #{joined}
                inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{@program_id}, '#{@end_date}')
                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                WHERE ps.start_date <= '#{@end_date}'
                #{categorise} AND ps.start_date >= '#{@start_date}'
                AND p.patient_id IN (#{ids})
                AND c.name = 'PATIENT TRANSFERRED OUT'").length rescue 0
  end

  def stopped_treatment_ever(ids, sex=nil)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end
    @dead = PatientState.find_by_sql("SELECT DISTINCT p.patient_id FROM patient p
                INNER JOIN  patient_program pp on pp.patient_id = p.patient_id #{joined}
                inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{@program_id}, '#{@end_date}')
                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                WHERE ps.start_date <= '#{@end_date}'
                #{categorise} AND p.patient_id IN (#{ids})
                AND c.name = 'TREATMENT STOPPED'").length rescue 0
  end

  def stopped_treatment(ids, sex=nil)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = p.patient_id"
    end
    @dead = PatientState.find_by_sql("SELECT DISTINCT p.patient_id FROM patient p
                INNER JOIN  patient_program pp on pp.patient_id = p.patient_id #{joined}
                inner join patient_state ps on ps.patient_program_id = pp.patient_program_id
                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, #{@program_id}, '#{@end_date}')
                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                WHERE ps.start_date <= '#{@end_date}'
                AND ps.start_date >= '#{@start_date}'
                #{categorise} AND p.patient_id IN (#{ids})
                AND c.name = 'TREATMENT STOPPED'").length rescue 0
  end

  # Treatment (Alive and Even Defaulters)
  def on_diet_ever
    @orders = Order.find_by_sql("SELECT DISTINCT orders.patient_id FROM orders \
                                  LEFT OUTER JOIN patient ON patient.patient_id = orders.patient_id \
                                  WHERE NOT order_id IN \
                                    (SELECT order_id FROM drug_order \
                                      WHERE drug_inventory_id IN \
                                        (SELECT drug_id FROM drug d WHERE (name LIKE '%lente%' AND name LIKE '%insulin%') OR \
                                        (name LIKE '%soluble%' AND name LIKE '%insulin%') OR (name LIKE '%glibenclamide%') OR \
                                        (name LIKE '%metformin%'))) \
                                    AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length rescue 0
  end

  def on_diet
    @orders = Order.find_by_sql("SELECT DISTINCT orders.patient_id FROM orders LEFT OUTER JOIN patient ON \
                                        patient.patient_id = orders.patient_id WHERE NOT order_id IN \
                                    (SELECT order_id FROM drug_order \
                                      WHERE drug_inventory_id IN \
                                        (SELECT drug_id FROM drug d WHERE (name LIKE '%lente%' AND name LIKE '%insulin%') OR \
                                        (name LIKE '%soluble%' AND name LIKE '%insulin%') OR (name LIKE '%glibenclamide%') OR \
                                        (name LIKE '%metformin%'))) AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + 
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length rescue 0
  end

  # Outcome: Defaulters
  def defaulters_ever(ids, sex)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = patient.patient_id"
    end
    names = ["PATIENT DIED", "PATIENT TRANSFERRED OUT", "TREATMENT STOPPED"]
    states = []
    names.each { |name|
      concept_name = ConceptName.find_all_by_name(name)
      states += ProgramWorkflowState.find(:first, :conditions => ["concept_id IN (?)",concept_name.map{|c|c.concept_id}] ).program_workflow_state_id
    }
    states = states.join(',')
    @orders = Order.find_by_sql("SELECT orders.patient_id, current_state_for_program(orders.patient_id, #{@program_id}, '#{@end_date}') AS state FROM orders
                                      LEFT OUTER JOIN patient ON patient.patient_id = orders.patient_id #{joined} \
                                      WHERE DATEDIFF('#{@end_date}', auto_expire_date)/30 > 2 \
                                      AND patient.voided = 0
                                      AND state NOT IN (#{states})
                                      AND patient.patient_id IN (#{ids}) AND \
                                      DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'  \
																			#{categorise} AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
																			concept_set IN (#{@asthma_id}, #{@epilepsy_id}, #{@diabetes_id}, #{@hypertensition_medication_id})) \
                                      GROUP BY patient_id").length rescue 0
  end
  
  def attending_ever(ids, sex)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = patient.patient_id"
    end
    
    @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders
                                      LEFT OUTER JOIN patient ON patient.patient_id = orders.patient_id  #{joined}\
                                      WHERE DATEDIFF('#{@end_date}', auto_expire_date)/30 <= 3 \
                                      AND patient.voided = 0
                                      AND patient.patient_id IN (#{ids})
                                      AND current_state_for_program(orders.patient_id, #{@program_id}, '#{@end_date}') NOT IN (#{@states}) AND \
                                      DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'  \
																			#{categorise} AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
																			concept_set IN (#{@asthma_id}, #{@epilepsy_id}, #{@diabetes_id}, #{@hypertensition_medication_id})) \
                                      GROUP BY patient_id").length rescue 0
  end

  def not_attending_ever(ids, sex)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = patient.patient_id"
    end

    @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders
                                      LEFT OUTER JOIN patient ON patient.patient_id = orders.patient_id  #{joined}\
                                      WHERE DATEDIFF('#{@end_date}', auto_expire_date)/30 > 3 \
                                      AND DATEDIFF('#{@end_date}', auto_expire_date)/30 <= 9
                                      AND patient.voided = 0
                                      AND patient.patient_id IN (#{ids})
                                      AND current_state_for_program(orders.patient_id, #{@program_id}, '#{@end_date}') NOT IN (#{@states}) AND \
                                      DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'  \
																			#{categorise} AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
																			concept_set IN (#{@asthma_id}, #{@epilepsy_id}, #{@diabetes_id}, #{@hypertensition_medication_id})) \
                                      GROUP BY patient_id").length rescue 0
  end

  def lost_followup_ever(ids, sex)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = patient.patient_id"
    end

    @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders
                                      LEFT OUTER JOIN patient ON patient.patient_id = orders.patient_id  #{joined}\
                                      WHERE DATEDIFF('#{@end_date}', auto_expire_date)/30 > 9
                                      AND patient.voided = 0
                                      AND current_state_for_program(orders.patient_id, #{@program_id}, '#{@end_date}') NOT IN (#{@states})
                                      AND patient.patient_id IN (#{ids}) AND \
                                      DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'  \
																			#{categorise} AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE \
																			concept_set IN (#{@asthma_id}, #{@epilepsy_id}, #{@diabetes_id}, #{@hypertensition_medication_id})) \
                                      GROUP BY patient_id").length rescue 0
  end

  def attending(ids, sex)
    if ! sex.blank?
      patient_initial = sex.split(//).first.upcase
      categorise = "AND (UCASE(pe.gender) = '#{sex.upcase}'
                                    OR UCASE(pe.gender) = '#{patient_initial}')"
      joined = "INNER JOIN person pe ON pe.person_id = patient.patient_id"
    end
    @orders = Order.find_by_sql("SELECT orders.patient_id FROM orders LEFT OUTER JOIN patient ON
                                        patient.patient_id = orders.patient_id #{joined}
                                         WHERE DATEDIFF('#{@end_date}', auto_expire_date)/30 <= 3
                                        AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'
                                        AND patient.voided = 0 AND patient.patient_id IN (#{ids})
                                        #{categorise} AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE
                                        concept_set IN (#{@asthma_id}, #{@epilepsy_id}, #{@diabetes_id}, #{@hypertensition_medication_id}))
                                        GROUP BY patient_id").length rescue 0
  end

  def defaulters(ids)
    names = ["PATIENT DIED", "PATIENT TRANSFERRED OUT", "TREATMENT STOPPED"]
    states = []
    names.each { |name|
      concept_name = ConceptName.find_all_by_name(name)
      states += ProgramWorkflowState.find(:first, :conditions => ["concept_id IN (?)",concept_name.map{|c|c.concept_id}] ).program_workflow_state_id
    }
    states = states.join(',')

    @orders = Order.find_by_sql("SELECT orders.patient_id  current_state_for_program(orders.patient_id, #{@program_id}, '#{@end_date}') AS state FROM orders LEFT OUTER JOIN patient ON
                                        patient.patient_id = orders.patient_id WHERE DATEDIFF('#{@end_date}', auto_expire_date)/30 > 2
                                        AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" +
        @start_date + "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'
                                        AND patient.voided = 0
                                        AND state NOT IN (#{states})
                                        AND patient.patient_id IN (#{ids})
                                        AND orders.concept_id IN (SELECT concept_id FROM concept_set WHERE 
                                        concept_set IN (#{@asthma_id}, #{@epilepsy_id}, #{@diabetes_id}, #{@hypertensition_medication_id}))
                                        GROUP BY patient_id").length rescue 0
  end

  # Maculopathy
  def maculopathy_ever
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'MACULOPATHY') OR UCASE(value_text) = 'MACULOPATHY' \
                                      AND patient.voided = 0 AND \
                                        DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "'").length rescue 0
  end

  def maculopathy
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE value_coded = (SELECT concept_id FROM concept_name \
		                                    WHERE name = 'MACULOPATHY') OR UCASE(value_text) = 'MACULOPATHY' \
		                                  AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') >= '" + @start_date +
        "' AND DATE_FORMAT(patient.date_created, '%Y-%m-%d') <= '" + @end_date + "' \
                                      AND patient.voided = 0").length rescue 0
  end

  #Hearf failure
  def heart_failure_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Cardiac') OR UCASE(value_text) = 'CARDIAC') \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        patient.date_created <= '" + @end_date + "'").length rescue 0
  end

  def heart_failure(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs 
                                 LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id 
		                             WHERE (concept_id = (SELECT concept_id FROM concept_name
		                             WHERE name = 'Cardiac') OR UCASE(value_text) = 'CARDIAC')
		                             AND patient.date_created >= '#{@start_date}'
                                 AND patient.date_created <= '#{@end_date}'
                                 AND patient.patient_id IN (#{ids})
                                 AND patient.voided = 0").length rescue 0
  end

  #mi
  def mi_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Myocardial injactia(MI)') OR value_text = 'Myocardial injactia(MI)') \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        patient.date_created <= '" + @end_date + "'").length rescue 0
  end

  def mi(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE (value_coded = (SELECT concept_id FROM concept_name \
		                                    WHERE name = 'Myocardial injactia(MI)') OR value_text = 'Myocardial injactia(MI)') \
		                                  AND patient.date_created >= '" + @start_date +
        "' AND patient.date_created <= '" + @end_date + "' \
                                    AND patient.patient_id IN (#{ids})
                                    AND patient.voided = 0").length rescue 0
  end

  def stroke_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'stroke' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'stroke') \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        patient.date_created <= '" + @end_date + "'").length rescue 0
  end

  def stroke(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE (value_coded = (SELECT concept_id FROM concept_name \
		                                    WHERE name = 'stroke' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'stroke') \
		                                  AND patient.date_created >= '" + @start_date +
        "' AND patient.date_created <= '" + @end_date + "' \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids})").length rescue 0
  end

  def tia_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'TIA' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'TIA') \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        patient.date_created <= '" + @end_date + "'").length rescue 0
  end

  def tia(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE (value_coded = (SELECT concept_id FROM concept_name \
		                                    WHERE name = 'TIA' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'TIA') \
		                                  AND patient.date_created >= '" + @start_date +
        "' AND patient.date_created <= '" + @end_date + "' \
                                     AND patient.patient_id IN (#{ids}) AND patient.voided = 0").length rescue 0
  end

  def ulcers_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Foot ulcers' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Foot ulcers') \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        patient.date_created <= '" + @end_date + "'").length rescue 0
  end

  def ulcers(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE (value_coded = (SELECT concept_id FROM concept_name \
		                                    WHERE name = 'Foot ulcers' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Foot ulcers') \
		                                  AND patient.date_created >= '" + @start_date +
        "' AND patient.date_created <= '" + @end_date + "'  AND patient.patient_id IN (#{ids})\
                                    AND patient.voided = 0").length rescue 0
  end

  def impotence_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Impotence' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Impotence') \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        patient.date_created <= '" + @end_date + "'").length rescue 0
  end

  def impotence(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE (value_coded = (SELECT concept_id FROM concept_name \
		                                    WHERE name = 'Impotence' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Impotence') \
		                                  AND patient.date_created >= '" + @start_date +
        "' AND patient.date_created <= '" + @end_date + "' \
                                     AND patient.patient_id IN (#{ids}) AND patient.voided = 0").length rescue 0
  end


  def amputation_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (value_coded = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Amputation' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Amputation') \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        patient.date_created <= '" + @end_date + "'").length rescue 0
  end

  def amputation(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE (value_coded = (SELECT concept_id FROM concept_name \
		                                    WHERE name = 'Amputation' and concept_name_type = 'FULLY_SPECIFIED') OR value_text = 'Amputation') \
		                                  AND patient.date_created >= '" + @start_date +
        "' AND patient.date_created <= '" + @end_date + "' \
                                     AND patient.patient_id IN (#{ids}) AND patient.voided = 0").length rescue 0
  end

  def kidney_failure_ever(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE (concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = 'Creatinine' and concept_name_type IS NULL) OR UCASE(value_text) = 'CREATININE') \
                                    AND patient.voided = 0  AND patient.patient_id IN (#{ids}) AND \
                                        patient.date_created <= '" + @end_date + "'").length rescue 0
  end

  def kidney_failure(ids)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE (concept_id = (SELECT concept_id FROM concept_name \
		                                    WHERE name = 'Creatinine' and concept_name_type IS NULL) OR UCASE(value_text) = 'CREATININE') \
		                                  AND patient.date_created >= '" + @start_date +
        "' AND patient.date_created <= '" + @end_date + "'  AND patient.patient_id IN (#{ids}) \
                                    AND patient.voided = 0").length rescue 0
  end

  def epilepsy_type_ever(type, answer)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                  LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
                                  WHERE concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = '" + type + "') 
                                      AND (value_coded = (SELECT concept_id FROM concept_name
                                          WHERE name = '" + answer + "')
                                          OR value_text = '" + answer + "')
                                    AND patient.voided = 0 AND \
                                        patient.date_created <= '" + @end_date + "' AND obs.voided = 0").length rescue 0
  end

  def epilepsy_type(type, answer)
    @orders = Order.find_by_sql("SELECT DISTINCT person_id FROM obs \
                                   LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id \
		                                 WHERE concept_id = (SELECT concept_id FROM concept_name \
                                      WHERE name = '" + type + "')
                                      AND (value_coded = (SELECT concept_id FROM concept_name
                                          WHERE name = '" + answer + "')
                                          OR value_text = '" + answer + "')
		                                  AND patient.date_created >= '" + @start_date +
        "' AND patient.date_created <= '" + @end_date + "' \
                                    AND patient.voided = 0 AND obs.voided = 0").length rescue 0
  end

  def non_epileptic(type, answer)
    #Epilepsy can only be confirmed once
    @orders = Order.find_by_sql("
                            SELECT * FROM obs
                            LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id
                            WHERE concept_id = (SELECT concept_id FROM concept_name
                            WHERE name = '" + type + "')
                            AND (value_coded = (SELECT concept_id FROM concept_name
                            WHERE name = '" + answer + "') OR value_text = '" + answer + "')
                            AND patient.date_created >= '" + @start_date + "'
                            AND patient.date_created <= '" + @end_date + "'
                            AND patient.voided = 0
                            AND obs.voided = 0
                            AND patient.patient_id NOT IN (
                                SELECT DISTINCT obs.person_id FROM obs
                                LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id
                                WHERE concept_id = (SELECT concept_id FROM concept_name
                                WHERE name = 'Confirm diagnosis of epilepsy')
                                AND (value_coded = (SELECT concept_id FROM concept_name
                                WHERE name = 'yes') OR value_text = 'yes')
                                AND patient.date_created >= '" + @start_date + "'
                                AND patient.date_created <= '" + @end_date + "'
                                AND patient.voided = 0
                                AND obs.voided = 0)").length rescue 0
  end

  def patient_on_drugs(ids, sex, drug)
	  @orders = Patient.find_by_sql("
              SELECT DISTINCT(p.patient_id) FROM patient p
              INNER JOIN person pe ON pe.person_id = p.patient_id
              INNER JOIN encounter e ON e.patient_id = p.patient_id
              INNER JOIN orders o ON o.encounter_id = e.encounter_id
              INNER JOIN concept_name c ON c.concept_id = o.concept_id
              WHERE c.name LIKE '%#{drug}%'
              AND e.voided = 0
              AND p.date_created >= '" + @start_date + "'
              AND p.date_created <= '" + @end_date + "'
              AND p.patient_id IN (#{ids})
              AND pe.gender LIKE '#{sex}%'").length rescue 0
  end

  def patient_ever_on_drugs(ids, sex, drug)
	  @orders = Patient.find_by_sql("
              SELECT DISTINCT(p.patient_id) FROM patient p
              INNER JOIN person pe ON pe.person_id = p.patient_id
              INNER JOIN encounter e ON e.patient_id = p.patient_id
              INNER JOIN orders o ON o.encounter_id = e.encounter_id
              INNER JOIN concept_name c ON c.concept_id = o.concept_id
              WHERE c.name LIKE '%#{drug}%'
              AND e.voided = 0
              AND p.date_created <= '" + @end_date + "'
              AND p.patient_id IN (#{ids})
              AND pe.gender LIKE '#{sex}%'").length rescue 0
  end

  def decrease_in_bp(ids, sex, reason=nil)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      if reason == "compare"
        total += 1 if compare_bp(patient.person_id.to_i) == true
      else
        total += 1 if low_bp(patient.person_id.to_i) == true
      end
    } rescue []
   
    return total
  end

  def controlled(ids, sex)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      bp_down = compare_bp(patient.person_id.to_i)
      bp_low = low_bp(patient.person_id.to_i)
      low_sugar = compare_sugar(patient.person_id.to_i)
      if bp_down == true || bp_low == true || low_sugar == true
        total += 1
      end
    } rescue []

    return total
  end
  
  def epilepsy_ever(ids, sex)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      epilepsy = current_vitals(Patient.find(patient.person_id), "Epilepsy", @end_date) rescue []
      total += 1 if ! epilepsy.blank?
    } rescue []

    return total
  end

  def burns_ever(ids, sex)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      burns = current_vitals(Patient.find(patient.person_id), "Burns", @end_date).to_s.match(/yes/i) rescue []
      total += 1 if ! burns.blank?
    } rescue []

    return total
  end

  def comp_amputation_ever(ids, sex)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      amputation = current_encounter(Patient.find(patient.person_id), "COMPLICATIONS", "COMPLICATIONS", @end_date).to_s.match(/Complications:  Amputation/i) rescue []
      total += 1 if ! amputation.blank?
    } rescue []

    return total
  end
  def comp_mi_ever(ids, sex)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      mi = current_encounter(Patient.find(patient.person_id), "COMPLICATIONS", "myocardial injactia", @end_date) rescue []
      total += 1 if ! mi.blank?
    } rescue []

    return total
  end

  def cardiovascular_ever(ids, sex)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      cardiac = current_encounter(Patient.find(patient.person_id), "COMPLICATIONS", "Cardiac", @end_date) #rescue []
      total += 1 if ! cardiac.blank?
    } rescue []

    return total
  end

  def blind_ever(ids, sex)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      cardiac = current_encounter(Patient.find(patient.person_id), "COMPLICATIONS", "Visual Blindness", @end_date) #rescue []
      total += 1 if ! cardiac.blank?
    } rescue []

    return total
  end

  def current_encounter(patient, enc, concept, session_date = Date.today)
    concept = ConceptName.find_by_name(concept).concept_id

    encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
      :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
        session_date ,patient.id, EncounterType.find_by_name(enc).id]).encounter_id rescue nil
    Observation.find(:all, :order => "obs_datetime DESC,date_created DESC", :conditions => ["encounter_id = ? AND concept_id = ?", encounter, concept]) rescue nil
  end

  def current_vitals(patient, vital_sign, session_date = Time.now())
    concept = ConceptName.find_by_sql("select concept_id from concept_name where name = '#{vital_sign}' and voided = 0").first.concept_id
    Observation.find_by_sql("SELECT * from obs where concept_id = '#{concept}' AND person_id = '#{patient.id}'
                    AND DATE(obs_datetime) <= '#{session_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC LIMIT 1").first rescue nil
  end

  def asthma_ever(ids, sex)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      asthma = current_encounter(Patient.find(patient.person_id), "ASTHMA MEASURE", "ASTHMA", @end_date).to_s.split(":")[1].match(/yes/i) rescue []
      total += 1 if ! asthma.blank?
    } rescue []

    return total
  end

  def decrease_in_sugar(ids, sex)
    total = 0
    Patient.find_by_sql("SELECT DISTINCT(person_id) FROM person
      WHERE person_id IN (#{ids})
      AND gender LIKE '#{sex}%'").each { |patient|
      total += 1 if compare_sugar(patient.person_id.to_i) == true
      
    } rescue []
   
    return total
  end

  def compare_sugar(patient_id)
    fasting = ConceptName.find_by_sql("select concept_id from concept_name where name = 'Fasting' and voided = 0").first.concept_id
    random = ConceptName.find_by_sql("select concept_id from concept_name where name = 'Random' and voided = 0").first.concept_id

    sys_obs = Observation.find_by_sql("SELECT * from obs where concept_id IN ('#{fasting}, #{random}') AND person_id = #{patient_id}
                    AND DATE(obs_datetime) <= '#{@end_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC") rescue []

    if sys_obs.length > 1
      first_sys = sys_obs.first.to_s.split(':')[1].to_i
      #raise sys_obs.first.obs_datetime.to_yaml
      previous_obs = Observation.find_by_sql("SELECT * from obs where concept_id IN ('#{fasting}, #{random}') AND person_id = #{patient_id}
                    AND DATE(obs_datetime) < '#{sys_obs.first.obs_datetime.to_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC").first.to_s.split(':')[1].to_i rescue 0
      return true if first_sys < previous_obs

    end
    return false
  end

  def compare_bp(patient_id)
    sys_concept = ConceptName.find_by_sql("select concept_id from concept_name where name = 'Systolic blood pressure' and voided = 0").first.concept_id
    dys_concept = ConceptName.find_by_sql("select concept_id from concept_name where name = 'Diastolic blood pressure' and voided = 0").first.concept_id

    sys_obs = Observation.find_by_sql("SELECT * from obs where concept_id = '#{sys_concept}' AND person_id = #{patient_id}
                    AND DATE(obs_datetime) <= '#{@end_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC") rescue []
    if sys_obs.length >= 2
      first_sys = sys_obs.first.to_s.split(':')[1].to_f
      #raise sys_obs.first.obs_datetime.to_yaml
      dys_obs = Observation.find_by_sql("SELECT * from obs where concept_id = '#{dys_concept}' AND person_id = #{patient_id}
                    AND DATE(obs_datetime) = '#{sys_obs.first.obs_datetime.to_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC").first.to_s.split(':')[1].to_f rescue []
      current_bp = first_sys / dys_obs
         
      second_sys = Observation.find_by_sql("SELECT * from obs where concept_id = '#{sys_concept}' AND person_id = #{patient_id}
                    AND DATE(obs_datetime) < '#{sys_obs.first.obs_datetime.to_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC").first.to_s.split(':')[1].to_f rescue []
      
      second_dys = Observation.find_by_sql("SELECT * from obs where concept_id = '#{dys_concept}' AND person_id = #{patient_id}
                    AND DATE(obs_datetime) < '#{sys_obs.first.obs_datetime.to_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC").first.to_s.split(':')[1].to_f rescue []
      previous_bp  = second_sys / second_dys
        
      return true if current_bp < previous_bp
    end
    return false
  end

  def low_bp(patient_id)
    sys_concept = ConceptName.find_by_sql("select concept_id from concept_name where name = 'Systolic blood pressure' and voided = 0").first.concept_id
    dys_concept = ConceptName.find_by_sql("select concept_id from concept_name where name = 'Diastolic blood pressure' and voided = 0").first.concept_id

    sys_obs = Observation.find_by_sql("SELECT * from obs where concept_id = '#{sys_concept}' AND person_id = #{patient_id}
                    AND DATE(obs_datetime) <= '#{@end_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC") rescue []
    if sys_obs.length >= 1
      first_sys = sys_obs.first.to_s.split(':')[1].to_f
      #raise sys_obs.first.obs_datetime.to_yaml
      dys_obs = Observation.find_by_sql("SELECT * from obs where concept_id = '#{dys_concept}' AND person_id = #{patient_id}
                    AND DATE(obs_datetime) = '#{sys_obs.first.obs_datetime.to_date}' AND voided = 0
                    ORDER BY  obs_datetime DESC, date_created DESC").first.to_s.split(':')[1].to_f rescue []
      current_bp = first_sys / dys_obs
      threshod = 140 / 90

      return true if current_bp < threshod
    end
    return false
  end


  def non_epileptic_ever(type, answer)
    #Epilepsy can only be confirmed once
    @orders = Order.find_by_sql("
                            SELECT * FROM obs
                            LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id
                            WHERE concept_id = (SELECT concept_id FROM concept_name
                            WHERE name = '" + type + "')
                            AND (value_coded = (SELECT concept_id FROM concept_name
                            WHERE name = '" + answer + "') OR value_text = '" + answer + "')
                            AND patient.date_created <= '" + @end_date + "'
                            AND patient.voided = 0
                            AND obs.voided = 0
                            AND patient.patient_id NOT IN (
                                SELECT DISTINCT obs.person_id FROM obs
                                LEFT OUTER JOIN patient ON patient.patient_id = obs.person_id
                                WHERE concept_id = (SELECT concept_id FROM concept_name
                                WHERE name = 'Confirm diagnosis of epilepsy')
                                AND (value_coded = (SELECT concept_id FROM concept_name
                                WHERE name = 'yes') OR value_text = 'yes')
                                AND patient.date_created <= '" + @end_date + "'
                                AND patient.voided = 0
                                AND obs.voided = 0)").length rescue 0
  end


  def ids_for_patient_on_drug_upto_end_date(end_date, drug_name, second_name=nil)
    ids = []
    if second_name.nil?
      ids = Patient.find(:all,
        :include =>{:orders => {:drug_order =>{:drug => {}}}},
        :conditions => ['drug.name LIKE ? AND patient.date_created <= ?',
          '%' + drug_name + '%', end_date]
      ).map{|patient| patient.patient_id}.uniq
    else
      ids = Patient.find(:all,
        :include =>{:orders => {:drug_order =>{:drug => {}}}},
        :conditions => ['drug.name LIKE ? AND drug.name LIKE ? AND patient.date_created <= ?',
          '%' + drug_name + '%', '%' + second_name + '%', end_date]
      ).map{|patient| patient.patient_id}.uniq
    end
    ids
  end
  
  def ids_for_patient_on_drug_btn_dates(start_date, end_date, drug_name, second_name=nil)
		ids = []
  	if second_name.nil?
			ids = Patient.find( :all,
        :include =>{:orders => {:drug_order =>{:drug => {}}}},
        :conditions => ['drug.name LIKE ? AND patient.date_created >= ?
										 									AND patient.date_created <= ?', '%' + drug_name + '%',
          start_date, end_date]
      ).map{|patient| patient.patient_id}.uniq
		else
			ids = Patient.find( :all,
        :include =>{:orders => {:drug_order =>{:drug => {}}}},
        :conditions => ['drug.name LIKE ? AND drug.name LIKE ? AND patient.date_created >= ?
										 									AND patient.date_created <= ?', '%' + drug_name + '%',
          '%' + second_name + '%', start_date, end_date]
      ).map{|patient| patient.patient_id}.uniq
		end
		ids
  end
  
  def ids_for_patients_with_complication_upto_end_date(complication, end_date)
		Patient.find(:all,
      :include => { :encounters => {:observations => {:answer_concept => {:concept_names => {}}}}},
      :conditions => ["concept_name.name = ?
							 									AND patient.date_created <= ?",complication,  end_date]
    ).map{|patient| patient.patient_id}.uniq
	end
	
	def ids_for_patients_with_complication_btn_dates(complication, start_date, end_date)
		Patient.find(:all,
      :include => { :encounters => {:observations => {:answer_concept => {:concept_names => {}}}}},
      :conditions => ["concept_name.name = ?
									 									AND patient.date_created >= ? AND patient.date_created <= ?",
        complication, start_date, end_date]
    ).map{|patient| patient.patient_id}.uniq
	end

  def chronic_care_ids
    Patient.find_by_sql("
                        SELECT DISTINCT p.patient_id FROM patient p
                        INNER JOIN patient_program pp ON p.patient_id = pp.patient_id
                        WHERE p.voided = 0
                        AND p.date_created <= '#{@end_date}'
                        AND pp.program_id = #{@program_id}").map{|patient|patient.patient_id.to_s}.join(',') rescue ""
  end
end
