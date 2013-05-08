
class EncountersController < ApplicationController

  def create
		
    User.current = User.find(@user["user_id"]) rescue nil

    Location.current = Location.find(params[:location_id] || session[:location_id]) rescue nil

    patient = Patient.find(params[:patient_id]) rescue nil

    if !patient.nil?

      type = EncounterType.find_by_name(params[:encounter_type]).id rescue nil

      if !type.nil?
        @encounter = Encounter.create(
          :patient_id => patient.id,
          :provider_id => (params[:user_id]),
          :encounter_type => type,
          :location_id => (session[:location_id] || params[:location_id])
        )

        @current = nil

        # raise @encounter.to_yaml

        if !params[:program].blank?

          @program = Program.find_by_concept_id(ConceptName.find_by_name(params[:program]).concept_id) rescue nil
					
          if !@program.nil?

            @program_encounter = ProgramEncounter.find_by_program_id(@program.id,
              :conditions => ["patient_id = ? AND DATE(date_time) = ?",
                patient.id, Date.today.strftime("%Y-%m-%d")])

            if @program_encounter.blank?

              @program_encounter = ProgramEncounter.create(
                :patient_id => patient.id,
                :date_time => Time.now,
                :program_id => @program.id
              )

            end

            ProgramEncounterDetail.create(
              :encounter_id => @encounter.id.to_i,
              :program_encounter_id => @program_encounter.id,
              :program_id => @program.id
            )
						
            @current = PatientProgram.find_by_program_id(@program.id,
              :conditions => ["patient_id = ? AND COALESCE(date_completed, '') = ''", patient.id])

            if @current.blank?

              @current = PatientProgram.create(
                :patient_id => patient.id,
                :program_id => @program.id,
                :date_enrolled => Time.now
              )

            end

          else

            redirect_to "/encounters/missing_program?program=#{params[:program]}" and return

          end

        end

        params[:concept].each do |key, value|

          if value.blank?
            next
          end

          if value.class.to_s.downcase != "array"

            concept = ConceptName.find_by_name(key.strip).concept_id rescue nil

            if !concept.nil? and !value.blank?

              if !@program.nil? and !@current.nil?

                selected_state = @program.program_workflows.map(&:program_workflow_states).flatten.select{|pws|
                  pws.concept.fullname.upcase() == value.upcase()
                }.first rescue nil

                @current.transition({
                    :state => "#{value}",
                    :start_date => Time.now,
                    :end_date => Time.now
                  }) if !selected_state.nil?
              end

              concept_type = nil
              if value.strip.match(/^\d+$/)

                concept_type = "number"

              elsif value.strip.match(/^\d{4}-\d{2}-\d{2}$/)

                concept_type = "date"

              elsif value.strip.match(/^\d{2}\:\d{2}\:\d{2}$/)

                concept_type = "time"

              else

                value_coded = ConceptName.find_by_name(value.strip) rescue nil

                if !value_coded.nil?

                  concept_type = "value_coded"

                else

                  concept_type = "text"

                end

              end

              obs = Observation.create(
                :person_id => @encounter.patient_id,
                :concept_id => concept,
                :location_id => @encounter.location_id,
                :obs_datetime => @encounter.encounter_datetime,
                :encounter_id => @encounter.id
              )

              case concept_type
              when "date"

                obs.update_attribute("value_datetime", value)

              when "time"

                obs.update_attribute("value_datetime", "#{Date.today.strftime("%Y-%m-%d")} " + value)

              when "number"

                obs.update_attribute("value_numeric", value)

              when "value_coded"

                obs.update_attribute("value_coded", value_coded.concept_id)
                obs.update_attribute("value_coded_name_id", value_coded.concept_name_id)

              else

                obs.update_attribute("value_text", value)

              end
							
            else
							
							key = key.gsub(" ", "_")
              redirect_to "/encounters/missing_concept?concept=#{key}" and return if !value.blank?

            end

          else

            value.each do |item|

              concept = ConceptName.find_by_name(key.strip).concept_id rescue nil

              if !concept.nil? and !item.blank?

                if !@program.nil? and !@current.nil?
                  selected_state = @program.program_workflows.map(&:program_workflow_states).flatten.select{|pws|
                    pws.concept.fullname.upcase() == item.upcase()
                  }.first rescue nil

                  @current.transition({
                      :state => "#{item}",
                      :start_date => Time.now,
                      :end_date => Time.now
                    }) if !selected_state.nil?
                end

                concept_type = nil
                if item.strip.match(/^\d+$/)

                  concept_type = "number"

                elsif item.strip.match(/^\d{4}-\d{2}-\d{2}$/)

                  concept_type = "date"

                elsif item.strip.match(/^\d{2}\:\d{2}\:\d{2}$/)

                  concept_type = "time"

                else

                  value_coded = ConceptName.find_by_name(item.strip) rescue nil

                  if !value_coded.nil?

                    concept_type = "value_coded"

                  else

                    concept_type = "text"

                  end

                end

                obs = Observation.create(
                  :person_id => @encounter.patient_id,
                  :concept_id => concept,
                  :location_id => @encounter.location_id,
                  :obs_datetime => @encounter.encounter_datetime,
                  :encounter_id => @encounter.id
                )

                case concept_type
                when "date"

                  obs.update_attribute("value_datetime", item)

                when "time"

                  obs.update_attribute("value_datetime", "#{Date.today.strftime("%Y-%m-%d")} " + item)

                when "number"

                  obs.update_attribute("value_numeric", item)

                when "value_coded"

                  obs.update_attribute("value_coded", value_coded.concept_id)
                  obs.update_attribute("value_coded_name_id", value_coded.concept_name_id)

                else

                  obs.update_attribute("value_text", item)

                end

              else

                redirect_to "/encounters/missing_concept?concept=#{item}" and return if !item.blank?

              end

            end

          end
					
        end if !params[:concept].nil?


        if !params[:prescription].nil?

          params[:prescription].each do |prescription|

            @suggestions = prescription[:suggestion] || ['New Prescription']
            @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil

            unless params[:location]
              session_date = session[:datetime] || params[:encounter_datetime] || Time.now()
            else
              session_date = params[:encounter_datetime] #Use encounter_datetime passed during import
            end
            # set current location via params if given
            Location.current_location = Location.find(params[:location]) if params[:location]

            @diagnosis = Observation.find(prescription[:diagnosis]) rescue nil
            @suggestions.each do |suggestion|
              unless (suggestion.blank? || suggestion == '0' || suggestion == 'New Prescription')
                @order = DrugOrder.find(suggestion)
                DrugOrder.clone_order(@encounter, @patient, @diagnosis, @order)
              else

                @formulation = (prescription[:formulation] || '').upcase
                @drug = Drug.find_by_name(@formulation) rescue nil
                unless @drug
                  flash[:notice] = "No matching drugs found for formulation #{prescription[:formulation]}"
                  # render :give_drugs, :patient_id => params[:patient_id]
                  # return
                end
                start_date = session_date
                auto_expire_date = session_date.to_date + prescription[:duration].to_i.days
                prn = prescription[:prn].to_i

                DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug,
                  start_date, auto_expire_date, [prescription[:morning_dose],
                    prescription[:afternoon_dose], prescription[:evening_dose],
                    prescription[:night_dose]], prescription[:type_of_prescription], prn)

              end
            end

          end

        end
				
      else

        redirect_to "/encounters/missing_encounter_type?encounter_type=#{params[:encounter_type]}" and return

      end

      if params[:encounter_type].downcase.strip == "baby delivery" and !params["concept"]["Time of delivery"].nil?

        baby = Baby.new(params[:user_id], params[:patient_id], session[:location_id], (session[:datetime] || Date.today))

        mother = Person.find(params[:patient_id]) rescue nil

        link = get_global_property_value("patient.registration.url").to_s rescue nil

        baby_id = baby.associate_with_mother("#{link}", "Baby #{((params[:baby].to_i - 1) rescue 1)}",
          "#{(!mother.nil? ? (mother.names.first.family_name rescue "Unknown") :
          "Unknown")}", params["concept"]["Gender]"], params["concept"]["Date of delivery]"]) # rescue nil

        # Baby identifier
        concept = ConceptName.find_by_name("Baby outcome").concept_id rescue nil

        obs = Observation.create(
          :person_id => @encounter.patient_id,
          :concept_id => concept,
          :location_id => @encounter.location_id,
          :obs_datetime => @encounter.encounter_datetime,
          :encounter_id => @encounter.id,
          :value_text => baby_id
        ) if !baby_id.nil?

      end
			
      @task = TaskFlow.new(params[:user_id] || User.first.id, patient.id)
			
      redirect_to params[:next_url] and return if !params[:next_url].nil?

      redirect_to @task.next_task.url and return

    end

  end

  def list_observations
    obs = []

    obs = Encounter.find(params[:encounter_id]).observations.collect{|o|
      [o.id, o.to_piped_s] rescue nil
    }.compact

    orders = Encounter.find(params[:encounter_id]).drug_orders.collect{|o|
      [o.id, o.to_piped_s] rescue nil
    }.compact

    obs = obs + orders

    render :text => obs.to_json
  end

  def void
    prog = ProgramEncounterDetail.find_by_encounter_id(params[:encounter_id]) rescue nil

    unless prog.nil?
      prog.void

      encounter = Encounter.find(params[:encounter_id]) rescue nil

      unless encounter.nil?
        encounter.void
      end

    end


    render :text => [].to_json
  end

  def list_encounters
    result = []

    program = ProgramEncounter.find(params[:program_id]) rescue nil

    unless program.nil?
      result = program.program_encounter_types.find(:all, :joins => [:encounter],
        :conditions => ["encounter.voided = 0"],
        :order => ["encounter_datetime DESC"]).collect{|e|
        [
          e.encounter_id, e.encounter.type.name.titleize,
          e.encounter.encounter_datetime.strftime("%H:%M"),
          e.encounter.creator,
          e.encounter.encounter_datetime.strftime("%d-%b-%Y")
        ]
      }
    end

    render :text => result.to_json
  end

  def static_locations
    search_string = (params[:search_string] || "").upcase
    extras = ["Health Facility", "Home", "TBA", "Other"]

    locations = []

    File.open(RAILS_ROOT + "/public/data/locations.txt", "r").each{ |loc|
      locations << loc if loc.upcase.strip.match(search_string)
    }

    if params[:extras]
      extras.each{|loc| locations << loc if loc.upcase.strip.match(search_string)}
    end

    render :text => "<li></li><li " + locations.map{|location| "value=\"#{location.strip}\">#{location.strip}" }.join("</li><li ") + "</li>"

  end

  def diagnoses

    search_string         = (params[:search] || '').upcase

    diagnosis_concepts    = Concept.find_by_name("Qech outpatient diagnosis list").concept_members.collect{|c| c.concept.fullname}.sort.uniq rescue ["Unknown"]

    @results = diagnosis_concepts.collect{|e| e}.delete_if{|x| !x.upcase.match(/^#{search_string}/)}

    render :text => "<li>" + @results.join("</li><li>") + "</li>"

  end

end