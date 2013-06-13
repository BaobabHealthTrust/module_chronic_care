
class TaskFlow

  attr_accessor :patient, :person, :user, :current_date, :tasks, :current_user_activities,
    :encounter_type, :url, :task_scopes, :task_list, :labels, :redirect_to, :current_program
    
  def initialize(user_id, patient_id, session_date = Date.today)
    self.patient = Patient.find(patient_id)
    self.user = User.find(user_id)
    self.current_date = session_date
		

    if File.exists?("#{Rails.root}/config/protocol_task_flow.yml")
      settings = YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["clinical.encounters.sequential.list"] rescue ""

      scopes = YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["scope"] rescue ""

      concepts = {}

      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["concept"].strip.split(",").map{|e| 
        s = e.split("|")
        concepts[s[0].downcase] = s[1]
      } rescue {}

      except_concepts = {}

      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["except_concept"].strip.split(",").map{|e| 
        s = e.split("|")
        except_concepts[s[0].downcase] = s[1]
      } rescue {}

      drug_concepts = {}

      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["drug_concept"].strip.split(",").map{|e| 
        s = e.split("|")
        drug_concepts[s[0].downcase] = s[1]
      } rescue {}

      special_fields = {}

      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["special_fields"].strip.split(",").map{|e| 
        s = e.split("|")
        special_fields[s[0].downcase] = s[1]
      } rescue {}

      self.labels = {}

      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["label"].strip.split(",").map{|e|
        s = e.split("|")
        self.labels[s[0].downcase] = s[1]
      } rescue {}

      self.tasks = settings.strip.split(",").collect{|i| i.downcase}

      list = scopes.strip.split(",").map{|e| e.split("|") }

      self.task_scopes = {}

      list.each{|item|
        self.task_scopes[item[0].downcase] = {
          :scope => item[1],
          :concept => (concepts[item[0].downcase] rescue nil),
          :except_concept => (except_concepts[item[0].downcase] rescue nil),
          :drug_concept => (drug_concepts[item[0].downcase] rescue nil),
          :special_field => (special_fields[item[0].downcase] rescue nil)
        }
      }
      
    end

    project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    self.current_user_activities = UserProperty.find_by_user_id_and_property(user_id,
      "#{project}.activities").property_value.split(",").collect{|a| a.downcase} rescue {}
      
  end

  def get_global_property_value(param)
    YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env
        }"][param] rescue nil
  end


  def epilepsy_next_task
    normal_flow = self.tasks

    flow = {}

    (0..(normal_flow.length-1)).each{|n|
      flow[normal_flow[n].downcase] = n+1
    }

    if self.current_user_activities.blank?

      self.encounter_type = "NO TASKS SELECTED"
      self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"

      return self

    end

    @patient = self.patient

    # tasks[task] = [weight, path, encounter_type, concept_id, exception_concept_id,
    #     scope, drug_concept_id, special_field_or_encounter_present, next_if_NOT_user_does_not_have_this_activity]

    tasks = {}

    normal_flow.each{|tsk|

      tasks[tsk.downcase] = [flow[tsk.downcase], "/protocol_patients/#{tsk.downcase.gsub(/\s/, "_")
          }?patient_id=#{self.patient.id}&user_id=#{self.user.id}", "#{tsk.upcase}",
        "#{self.task_scopes[tsk.downcase][:concept]}", "#{self.task_scopes[tsk.downcase][:except_concept]}",
        "#{self.task_scopes[tsk.downcase][:scope]}", "#{self.task_scopes[tsk.downcase][:drug_concept]}",
        "#{self.task_scopes[tsk.downcase][:special_field]}",
        (self.current_user_activities.include?(tsk.downcase))
      ]

    }

    sorted_tasks = {}

    tasks.each{|t,v|
      sorted_tasks[v[0]] = t
    }

    self.task_list = tasks

    sorted_tasks = sorted_tasks.sort



      # next if tasks[tsk][8] == false
      # If user does not have this activity, goto the patient dashboard

			encounters =  [
                      'VITALS','FAMILY HISTORY','SOCIAL HISTORY', 'LAB RESULTS',
											'CLINIC VISIT', 'MEDICAL HISTORY','TREATMENT', 'OUTCOME'
                     ]
		observation = Observation.find(:all,
												:conditions => ["encounter_id = ?", Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                        :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date, self.patient.id,EncounterType.find_by_name("update hiv status").id]).encounter_id]).to_s rescue ""

		if observation.match(/Refer to HTC:  Yes/i)
						self.encounter_type = "HIV STATUS"
						self.url = "/protocol_patients/hiv_status?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
		 end

			my_activities = self.current_user_activities.map(&:upcase)

			encounters.each do |tsk|

			found = false
			case tsk
				when "CLINIC VISIT"
					next if ! self.current_user_activities.include?(tsk.downcase)
          visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name("DIABETES HYPERTENSION INITIAL VISIT").id])

					next if !visit.blank?

					self.encounter_type = 'CLINIC VISIT'
					self.url = "/protocol_patients/clinic_visit?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					return self

        when "VITALS"
					next if ! self.current_user_activities.include?(tsk.downcase)
          vitals = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !vitals.blank?
					self.encounter_type = 'VITALS'
					self.url = "/protocol_patients/vitals?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "FAMILY HISTORY"
					next if ! self.current_user_activities.include?('medical history')
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "FAMILY MEDICAL HISTORY"
					end
					next if found == true
          history = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name('FAMILY MEDICAL HISTORY').id])

					next if !history.blank?
					self.encounter_type = 'FAMILY MEDICAL HISTORY'
					self.url = "/protocol_patients/family_history?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"

					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "SOCIAL HISTORY"
					next if ! self.current_user_activities.include?(tsk.downcase)
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "SOCIAL HISTORY"
					end
					next if found == true

          history = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !history.blank?
					self.encounter_type = 'SOCIAL HISTORY'
					self.url = "/protocol_patients/social_history?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "MEDICAL HISTORY"
					next if ! self.current_user_activities.include?(tsk.downcase)
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "MEDICAL HISTORY"
					end
					next if found == true
          history = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !history.blank?
					self.encounter_type = 'MEDICAL HISTORY'
					self.url = "/protocol_patients/medical_history?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
				  if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

        when "UPDATE HIV STATUS"
					next if ! self.current_user_activities.include?("hiv status")
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "UPDATE HIV STATUS"
					end
					next if found == true

					next if @patient.person.observations.to_s.match(/hiv status/i)
          hiv_status = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])



					if hiv_status.observations.map{|s|s.to_s.split(':').last.strip}.include?('Positive')
            next
          end if not hiv_status.blank?
					self.encounter_type = "HIV STATUS"
					self.url = "/protocol_patients/hiv_status?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?("HIV STATUS")
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "ASTHMA MEASURE"
					next if ! self.current_user_activities.include?(tsk.downcase)
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !assessment.blank?
					self.encounter_type = "ASTHMA MEASURE"
					self.url = "/protocol_patients/asthma_measure?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "COMPLICATIONS"
					next if ! self.current_user_activities.include?(tsk.downcase)
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])
					next if !assessment.blank?
					self.encounter_type = "COMPLICATIONS"
					self.url = "/protocol_patients/complications?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "TREATMENT"
					next if ! self.current_user_activities.include?(tsk.downcase)
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !assessment.blank?
					self.encounter_type = "TREATMENT"
					self.url = "/protocol_patients/treatment?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

			when "LAB RESULTS"
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "LAB RESULTS"
					end
					next if found == true
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])
					next if !assessment.blank?
					self.encounter_type = "LAB RESULTS"
					self.url = "/protocol_patients/lab_results?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end
		end

		self.encounter_type = 'NONE'
		self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"
		return self
		end
	end

	def asthma_next_task
    normal_flow = self.tasks

    flow = {}

    (0..(normal_flow.length-1)).each{|n|
      flow[normal_flow[n].downcase] = n+1
    }

    if self.current_user_activities.blank?

      self.encounter_type = "NO TASKS SELECTED"
      self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"

      return self

    end

    @patient = self.patient

    # tasks[task] = [weight, path, encounter_type, concept_id, exception_concept_id,
    #     scope, drug_concept_id, special_field_or_encounter_present, next_if_NOT_user_does_not_have_this_activity]

    tasks = {}

    normal_flow.each{|tsk|

      tasks[tsk.downcase] = [flow[tsk.downcase], "/protocol_patients/#{tsk.downcase.gsub(/\s/, "_")
          }?patient_id=#{self.patient.id}&user_id=#{self.user.id}", "#{tsk.upcase}",
        "#{self.task_scopes[tsk.downcase][:concept]}", "#{self.task_scopes[tsk.downcase][:except_concept]}",
        "#{self.task_scopes[tsk.downcase][:scope]}", "#{self.task_scopes[tsk.downcase][:drug_concept]}",
        "#{self.task_scopes[tsk.downcase][:special_field]}",
        (self.current_user_activities.include?(tsk.downcase))
      ]

    }

    sorted_tasks = {}

    tasks.each{|t,v|
      sorted_tasks[v[0]] = t
    }

    self.task_list = tasks

    sorted_tasks = sorted_tasks.sort



      # next if tasks[tsk][8] == false
      # If user does not have this activity, goto the patient dashboard

			encounters =  [
                      'CLINIC VISIT','VITALS','FAMILY HISTORY','MEDICAL HISTORY','SOCIAL HISTORY',
											'UPDATE HIV STATUS','ASTHMA MEASURE','COMPLICATIONS','TREATMENT',
											'OUTCOME'
                     ]
		observation = Observation.find(:all,
												:conditions => ["encounter_id = ?", Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                        :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date, self.patient.id,EncounterType.find_by_name("update hiv status").id]).encounter_id]).to_s rescue ""

		if observation.match(/Refer to HTC:  Yes/i)
						self.encounter_type = "HIV STATUS"
						self.url = "/protocol_patients/hiv_status?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
		 end

			my_activities = self.current_user_activities.map(&:upcase)
			
			encounters.each do |tsk|

			found = false
			case tsk
				when "CLINIC VISIT"
					next if ! self.current_user_activities.include?(tsk.downcase)
          visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name("DIABETES HYPERTENSION INITIAL VISIT").id])

					next if !visit.blank?

					self.encounter_type = 'CLINIC VISIT'
					self.url = "/protocol_patients/clinic_visit?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					return self

        when "VITALS"
					next if ! self.current_user_activities.include?(tsk.downcase)
          vitals = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !vitals.blank?
					self.encounter_type = 'VITALS'
					self.url = "/protocol_patients/vitals?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "FAMILY HISTORY"
					next if ! self.current_user_activities.include?('medical history')
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "FAMILY MEDICAL HISTORY"
					end
					next if found == true
          history = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name('FAMILY MEDICAL HISTORY').id])

					next if !history.blank?
					self.encounter_type = 'FAMILY MEDICAL HISTORY'
					self.url = "/protocol_patients/family_history?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"

					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "SOCIAL HISTORY"
					next if ! self.current_user_activities.include?(tsk.downcase)
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "SOCIAL HISTORY"
					end
					next if found == true

          history = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !history.blank?
					self.encounter_type = 'SOCIAL HISTORY'
					self.url = "/protocol_patients/social_history?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "MEDICAL HISTORY"
					next if ! self.current_user_activities.include?(tsk.downcase)
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "MEDICAL HISTORY"
					end
					next if found == true
          history = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !history.blank?
					self.encounter_type = 'MEDICAL HISTORY'
					self.url = "/protocol_patients/medical_history?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
				  if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

        when "UPDATE HIV STATUS"
					next if ! self.current_user_activities.include?("hiv status")
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "UPDATE HIV STATUS"
					end
					next if found == true

					next if @patient.person.observations.to_s.match(/hiv status/i)
          hiv_status = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])



					if hiv_status.observations.map{|s|s.to_s.split(':').last.strip}.include?('Positive')
            next
          end if not hiv_status.blank?
					self.encounter_type = "HIV STATUS"
					self.url = "/protocol_patients/hiv_status?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?("HIV STATUS")
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "ASTHMA MEASURE"
					next if ! self.current_user_activities.include?(tsk.downcase)
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !assessment.blank?
					self.encounter_type = "ASTHMA MEASURE"
					self.url = "/protocol_patients/asthma_measure?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "COMPLICATIONS"
					next if ! self.current_user_activities.include?(tsk.downcase)
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])
					next if !assessment.blank?
					self.encounter_type = "COMPLICATIONS"
					self.url = "/protocol_patients/complications?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "TREATMENT"
					next if ! self.current_user_activities.include?(tsk.downcase)
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !assessment.blank?
					self.encounter_type = "TREATMENT"
					self.url = "/protocol_patients/treatment?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

		end

		self.encounter_type = 'NONE'
		self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"
		return self
		end
	end

  def next_task
    
    # scope: [ TODAY | EXISTS | CURRENT PROGRAM | RECENT ]

    normal_flow = self.tasks

    flow = {}

    (0..(normal_flow.length-1)).each{|n|
      flow[normal_flow[n].downcase] = n+1
    }
		
    if self.current_user_activities.blank?

      self.encounter_type = "NO TASKS SELECTED"
      self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"

      return self

    end

    @patient = self.patient

    # tasks[task] = [weight, path, encounter_type, concept_id, exception_concept_id, 
    #     scope, drug_concept_id, special_field_or_encounter_present, next_if_NOT_user_does_not_have_this_activity]

    tasks = {}

    normal_flow.each{|tsk|
      
      tasks[tsk.downcase] = [flow[tsk.downcase], "/protocol_patients/#{tsk.downcase.gsub(/\s/, "_")
          }?patient_id=#{self.patient.id}&user_id=#{self.user.id}", "#{tsk.upcase}", 
        "#{self.task_scopes[tsk.downcase][:concept]}", "#{self.task_scopes[tsk.downcase][:except_concept]}",
        "#{self.task_scopes[tsk.downcase][:scope]}", "#{self.task_scopes[tsk.downcase][:drug_concept]}",
        "#{self.task_scopes[tsk.downcase][:special_field]}", 
        (self.current_user_activities.include?(tsk.downcase))
      ]

    }

    sorted_tasks = {}

    tasks.each{|t,v|
      sorted_tasks[v[0]] = t
    }

    self.task_list = tasks
		
    sorted_tasks = sorted_tasks.sort

    

      # next if tasks[tsk][8] == false
      # If user does not have this activity, goto the patient dashboard
			
			encounters =  [
                      'CLINIC VISIT','VITALS','FAMILY HISTORY','SOCIAL HISTORY','GENERAL HEALTH',
											'UPDATE HIV STATUS','LAB RESULTS','COMPLICATIONS','TREATMENT',
											'OUTCOME','ASSESSMENT'
                     ]
			#program = current_program
			#if program.upcase == "ASTHMA PROGRAM"
			#	encounters =  [
      #                'CLINIC VISIT','VITALS','FAMILY HISTORY','SOCIAL HISTORY',
			#								'UPDATE HIV STATUS','TREATMENT',
			#								'OUTCOME'
     #                ]
		#	end
		  observation = Observation.find(:all,
												:conditions => ["encounter_id = ?", Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                        :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date, self.patient.id,EncounterType.find_by_name("update hiv status").id]).encounter_id]).to_s rescue ""
		 if observation.match(/Refer to HTC:  Yes/i)
						self.encounter_type = "HIV STATUS"
						self.url = "/protocol_patients/hiv_status?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
		 end

			my_activities = self.current_user_activities.map(&:upcase)
			
			encounters.each do |tsk|
			
			found = false
			case tsk
				when "CLINIC VISIT"
					next if ! self.current_user_activities.include?(tsk.downcase)
          visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name("DIABETES HYPERTENSION INITIAL VISIT").id])

					next if !visit.blank?
					
					self.encounter_type = 'CLINIC VISIT'
					self.url = "/protocol_patients/clinic_visit?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					return self

        when "VITALS"
					next if ! self.current_user_activities.include?(tsk.downcase)
          vitals = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !vitals.blank?
					self.encounter_type = 'VITALS'
					self.url = "/protocol_patients/vitals?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "FAMILY HISTORY"
					next if ! self.current_user_activities.include?('medical history')
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "FAMILY MEDICAL HISTORY"
					end
					next if found == true
          history = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name('FAMILY MEDICAL HISTORY').id])

					next if !history.blank?
					self.encounter_type = 'FAMILY MEDICAL HISTORY'
					self.url = "/protocol_patients/family_history?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "SOCIAL HISTORY"
					next if ! self.current_user_activities.include?(tsk.downcase)
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "SOCIAL HISTORY"
					end
					next if found == true

          history = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !history.blank?
					self.encounter_type = 'SOCIAL HISTORY'
					self.url = "/protocol_patients/social_history?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "GENERAL HEALTH"
					next if ! self.current_user_activities.include?(tsk.downcase)
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "GENERAL HEALTH"
					end
					next if found == true
          history = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !history.blank?
					self.encounter_type = 'GENERAL HEALTH'
					self.url = "/protocol_patients/general_health?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
				  if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

        when "UPDATE HIV STATUS"
					next if ! self.current_user_activities.include?('hiv status')
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "UPDATE HIV STATUS"
					end
					next if found == true

					next if @patient.person.observations.to_s.match(/hiv status/i)
          hiv_status = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])
					
					

					if hiv_status.observations.map{|s|s.to_s.split(':').last.strip}.include?('Positive')
            next
          end if not hiv_status.blank?
					self.encounter_type = "HIV STATUS"
					self.url = "/protocol_patients/hiv_status?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?("HIV STATUS")
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "ASSESSMENT"
					next if ! self.current_user_activities.include?(tsk.downcase)
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])
					
					next if !assessment.blank?
					self.encounter_type = "ASSESSMENT"
					self.url = "/protocol_patients/assessment?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "COMPLICATIONS"
					next if ! self.current_user_activities.include?(tsk.downcase)
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])
					next if !assessment.blank?
					self.encounter_type = "COMPLICATIONS"
					self.url = "/protocol_patients/complications?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "TREATMENT"
					next if ! self.current_user_activities.include?(tsk.downcase)
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])

					next if !assessment.blank?
					self.encounter_type = "TREATMENT"
					self.url = "/protocol_patients/treatment?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end

				when "LAB RESULTS"
					self.patient.encounters.each do | enc |
					 found = true if enc.name.upcase == "LAB RESULTS"
					end
					next if found == true
					assessment = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                  self.current_date.to_date.to_date,self.patient.id,EncounterType.find_by_name(tsk).id])
					next if !assessment.blank?
					self.encounter_type = "LAB RESULTS"
					self.url = "/protocol_patients/lab_results?patient_id=#{self.patient.id}&user_id=#{@user["user_id"]}"
					if ! my_activities.include?(tsk)
						redirect_to "/patients/show/#{self.patient.id}?user_id=#{self.user.id}&disable=true" and return
					else
						return self
					end
			end
					
		end

		self.encounter_type = 'NONE'
		self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"
		return self

=begin
      if tasks[tsk][8] == false        
        self.encounter_type = tsk
        self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"
        return self
      end
			
      case tasks[tsk][2]
      when "VITALS"
				
        checked_already = false

        if !tasks[tsk][3].blank? && checked_already == false    # Check for presence of specific concept_id
          available = Encounter.find(:all, :joins => [:observations], :conditions =>
              ["patient_id = ? AND encounter_type = ? AND obs.concept_id = ? AND DATE(encounter_datetime) = ?",
              self.patient.id, EncounterType.find_by_name(tasks[tsk][2]), tasks[tsk][3], self.current_date.to_date]) rescue []

          checked_already = tasks[tsk][7]
          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        if !tasks[tsk][4].blank? && checked_already == false   # Check for concept exclusions from encounter_type group
          available = Encounter.find(:all, :joins => [:observations], :conditions =>
              ["patient_id = ? AND encounter_type = ? AND NOT obs.concept_id = ? AND DATE(encounter_datetime) = ?",
              self.patient.id, EncounterType.find_by_name(tasks[tsk][2]), tasks[tsk][4], self.current_date.to_date]) rescue []

          checked_already = tasks[tsk][7]
          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        if !tasks[tsk][6].blank? && checked_already == false   # Check for drug concept if available
          available = self.patient.orders.all(:conditions => ["concept_id = ? AND start_date = ?",
              tasks[tsk][6], self.current_date.to_date]) rescue []

          checked_already = tasks[tsk][7]
          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        # Else check for availability of encounter_type
        if checked_already == false
          available = Encounter.find(:all, :joins => [:observations], :conditions =>
              ["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
              self.patient.id, EncounterType.find_by_name(tasks[tsk][2]), self.current_date.to_date]) rescue []

          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        self.encounter_type = tsk

        if normal_flow[0].downcase == tsk.downcase
          self.url = tasks[tsk][1]
        else
          self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"
        end
        return self
      when "RECENT"

        checked_already = false

        if !tasks[tsk][3].blank? && checked_already == false    # Check for presence of specific concept_id
          available = Encounter.find(:all, :joins => [:observations], :conditions =>
              ["patient_id = ? AND encounter_type = ? AND obs.concept_id = ? " +
                "AND (DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ?)",
              self.patient.id, EncounterType.find_by_name(tasks[tsk][2]), tasks[tsk][3],
              (self.current_date.to_date - 6.month), (self.current_date.to_date + 6.month)]) rescue []

          checked_already = tasks[tsk][7]
          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        if !tasks[tsk][4].blank? && checked_already == false   # Check for concept exclusions from encounter_type group
          available = Encounter.find(:all, :joins => [:observations], :conditions =>
              ["patient_id = ? AND encounter_type = ? AND NOT obs.concept_id = ? " +
                "AND (DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ?)",
              self.patient.id, EncounterType.find_by_name(tasks[tsk][2]), tasks[tsk][4],
              (self.current_date.to_date - 6.month), (self.current_date.to_date + 6.month)]) rescue []

          checked_already = tasks[tsk][7]
          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        if !tasks[tsk][6].blank? && checked_already == false   # Check for drug concept if available
          available = self.patient.orders.all(:conditions => ["concept_id = ? AND start_date = ? " +
                "AND (DATE(start_date) >= ? AND DATE(start_date) <= ?)",
              tasks[tsk][6], (self.current_date.to_date - 6.month), (self.current_date.to_date + 6.month)]) rescue []

          checked_already = tasks[tsk][7]
          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        # Else check for availability of encounter_type
        if checked_already == false
          available = Encounter.find(:all, :joins => [:observations], :conditions =>
              ["patient_id = ? AND encounter_type = ? " +
                "AND (DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ?)",
              self.patient.id, EncounterType.find_by_name(tasks[tsk][2]),
              (self.current_date.to_date - 6.month), (self.current_date.to_date + 6.month)]) rescue []

          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        self.encounter_type = tsk

        if normal_flow[0].downcase == tsk.downcase
          self.url = tasks[tsk][1]
        else
          self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"
        end
        return self
      when "EXISTS"

        checked_already = false

        if !tasks[tsk][3].blank? && checked_already == false    # Check for presence of specific concept_id
          available = Encounter.find(:all, :joins => [:observations], :conditions =>
              ["patient_id = ? AND encounter_type = ? AND obs.concept_id = ?",
              self.patient.id, EncounterType.find_by_name(tasks[tsk][2]), tasks[tsk][3]]) rescue []

          checked_already = tasks[tsk][7]
          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        if !tasks[tsk][4].blank? && checked_already == false   # Check for concept exclusions from encounter_type group
          available = Encounter.find(:all, :joins => [:observations], :conditions =>
              ["patient_id = ? AND encounter_type = ? AND NOT obs.concept_id = ?",
              self.patient.id, EncounterType.find_by_name(tasks[tsk][2]), tasks[tsk][4]]) rescue []

          checked_already = tasks[tsk][7]
          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        if !tasks[tsk][6].blank? && checked_already == false   # Check for drug concept if available
          available = self.patient.orders.all(:conditions => ["concept_id = ?",
              tasks[tsk][6]]) rescue []

          checked_already = tasks[tsk][7]
          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        # Else check for availability of encounter_type
        if checked_already == false
          available = Encounter.find(:all, :joins => [:observations], :conditions =>
              ["patient_id = ? AND encounter_type = ?",
              self.patient.id, EncounterType.find_by_name(tasks[tsk][2])]) rescue []

          if available.length > 0
            if normal_flow[0].downcase == tsk.downcase
              normal_flow -= [tsk.downcase]
              next
            end
          end
        end

        self.encounter_type = tsk

        if normal_flow[0].downcase == tsk.downcase
          self.url = tasks[tsk][1]
        else
          self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"
        end
        return self
      end

    end

    #self.encounter_type = 'Visit complete ...'
    self.encounter_type = 'NONE'
    self.url = "/patients/show/#{self.patient.id}?user_id=#{self.user.id}"
    return self
=end
  end

end

class String

  def to_bool

    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)

    return false if self == false || self.blank? || self =~ (/(false|f|no|n|0)$/i)

    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")

  end

end