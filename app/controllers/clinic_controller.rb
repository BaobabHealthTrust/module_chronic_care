
class ClinicController < ApplicationController

  def index
		#raise Location.current_health_center.name.to_yaml
    User.current = User.find(@user["user_id"]) rescue nil

    Location.current = Location.find(params[:location_id] || session[:location_id]) rescue nil

    @location = Location.find(params[:location_id] || session[:location_id]) rescue nil

		lock = params[:location_id] || session[:location_id]

    session[:location_id] = @location.id if !@location.nil?
    
    #redirect_to "/patients/show/#{params[:ext_patient_id]}?user_id=#{params[:user_id]}&location_id=#{
    #params[:location_id]}" if !params[:ext_patient_id].nil?

		redirect_to "/patients/confirm/#{params[:ext_patient_id]}?found_person_id=#{params[:ext_patient_id]}&location_id=#{
    lock}&user_id=#{params[:user_id]}" and return if !params[:ext_patient_id].nil?

    @project = get_global_property_value("project.name").split(/\s+/).map(&:first).to_s rescue "Unknown"

   

    @facility = Location.current_health_center.name rescue get_global_property_value("facility.name") rescue "Unknown"

    @patient_registration = get_global_property_value("patient.registration.url") rescue ""

    @link = get_global_property_value("user.management.url").to_s rescue nil

    if @link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end

    @selected = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env
        }"]["demographic.fields"].split(",") rescue []
    if current_program.blank?
      session[:selected_program] = "HYPERTENSION PROGRAM"
    end

  end

	def programs
    session[:selected_program] = params[:program] + " PROGRAM"
    @user_id = params[:user_id]
    @location_id = params[:location_id]
    if params[:patient_id]
      redirect_to "/patients/show/#{params[:patient_id]}?user_id=#{params[:user_id]}"
    else
      redirect_to "/clinic/index?user_id=#{params[:user_id]}&location_id=#{params[:location_id]}"
    end
	end

  def user_login

    link = get_global_property_value("user.management.url").to_s rescue nil

    if link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end

    host = request.host_with_port rescue ""

    redirect_to "#{link}/login?ext=true&src=#{host}" and return if params[:ext_user_id].nil?

  end

  def user_logout

    link = get_global_property_value("user.management.url").to_s rescue nil


    if link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end

    session[:datetime] = nil
    session[:location_id] = nil

    host = request.host_with_port rescue ""

    redirect_to "#{link}/logout/#{params[:id]}?ext=true&src=#{host}" and return if params[:ext_user_id].nil?

  end

  def set_datetime
  end

  def update_datetime
    unless params[:set_day]== "" or params[:set_month]== "" or params[:set_year]== ""
      # set for 1 second after midnight to designate it as a retrospective date
      date_of_encounter = Time.mktime(params[:set_year].to_i,
        params[:set_month].to_i,
        params[:set_day].to_i,0,0,1)
      session[:datetime] = date_of_encounter #if date_of_encounter.to_date != Date.today
    end

    redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{params[:location_id]}"
  end

  def reset_datetime
    session[:datetime] = nil
    redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{params[:location_id]}" and return
  end

  def administration

    @link = get_global_property_value("user.management.url").to_s rescue nil

    if @link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end

    @host = request.host_with_port rescue ""

    render :layout => false
  end

  def merge_menu
     render :layout => "report"
  end

 def merge_similar_patients
    if request.method == :post
      raise params[:patient_ids].to_yaml
      params[:patient_ids].split(":").each do | ids |
        master = ids.split(',')[0].to_i
        slaves = ids.split(',')[1..-1]
        ( slaves || [] ).each do | patient_id  |
          next if master == patient_id.to_i
          Patient.merge(master,patient_id.to_i, params[:user_id])
        end
      end
      #render :text => "showMessage('Successfully merged patients')" and return
    end
    redirect_to :action => "merge_menu", :user_id => params[:user_id] and return
  end

  def search_all
    search_str = params[:search_str]
    side = params[:side]
    search_by_identifier = search_str.match(/[0-9]+/).blank? rescue false

    unless search_by_identifier
      patients = PatientIdentifier.find(:all, :conditions => ["voided = 0 AND (identifier LIKE ?)",
                                                              "%#{search_str}%"],:limit => 10).map{| p |p.patient}
    else
      given_name = search_str.split(' ')[0] rescue ''
      family_name = search_str.split(' ')[1] rescue ''
      patients = PersonName.find(:all ,:joins => [:person => [:patient]], :conditions => ["person.voided = 0 AND family_name LIKE ? AND given_name LIKE ?",
                                                                                          "#{family_name}%","%#{given_name}%"],:limit => 10).collect{|pn|pn.person.patient}
    end
    @html = <<EOF
<html>
<head>
<style>
  .color_blue{
    border-style:solid;
  }
  .color_white{
    border-style:solid;
  }

  th{
    border-style:solid;
  }
</style>
</head>
<body>
<br/>
<table class="data_table" width="100%">
EOF

    color = 'blue'
    patients.each do |patient|
      next if patient.person.blank?
      next if patient.person.addresses.blank?
      if color == 'blue'
        color = 'white'
      else
        color='blue'
      end
      bean = PatientService.get_patient(patient.person)
      total_encounters = patient.encounters.count rescue nil
      latest_visit = patient.encounters.last.encounter_datetime.strftime("%a, %d-%b-%y") rescue nil
      @html+= <<EOF
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Name:&nbsp;#{bean.name || '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Age:&nbsp;#{bean.age || '&nbsp;'}</td>
</tr>
<tr>
  <td colspan=2 class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Guardian:&nbsp;#{bean.guardian rescue '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">National ID:&nbsp;#{bean.national_id rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">TA:&nbsp;#{bean.home_district rescue '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Total Encounters:&nbsp;#{total_encounters rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Latest Visit:&nbsp;#{latest_visit rescue '&nbsp;'}</td>
</tr>
EOF
    end

    @html+="</table></body></html>"
    render :text => @html ; return
  end


  def current_center
    if request.post?
      location = Location.find_by_name(params[:current_center])
      current_center = GlobalProperty.find_by_property("current_health_center_name")
       
      if current_center.nil?
        current_center = GlobalProperty.new
        current_center.property = "current_health_center_name"
        current_center.property_value = params[:current_center]
        current_center.save
      else
        current_center = GlobalProperty.find_by_property("current_health_center_name")
        current_center.property_value = params[:current_center]
        current_center.save
      end

      current_id = get_global_property_value("current_health_center_id")
      if current_id.nil?
        current_id = GlobalProperty.new
        current_id.property = "current_health_center_id"
        current_id.property_value = location.id
        current_id.save
      else
        current_id = GlobalProperty.find_by_property("current_health_center_id")
        current_id.property_value = location.id
        current_id.save
      end
			redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
		end
  end

  def appointment
    if request.post?
      appointment = get_global_property_value("auto_set_appointment") rescue nil
      if appointment.nil?
        appointment= GlobalProperty.new
        appointment.property = "auto_set_appointment"
        appointment.property_value = params[:appointment]
        appointment.save
      else
        appointment = GlobalProperty.find_by_property("auto_set_appointment")
        appointment.property_value = params[:appointment]
        appointment.save
      end
			redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
		end
  end

  def prescriptions
    if request.post?
      appointment = get_global_property_value("prescription.types") rescue nil
      if appointment.nil?
        appointment= GlobalProperty.new
        appointment.property = "prescription.types"
        appointment.property_value = params[:prescription]
        appointment.save
      else
        appointment = GlobalProperty.find_by_property("prescription.types")
        appointment.property_value = params[:prescription]
        appointment.save
      end
			redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
		end
  end


	def vitals
	  if request.post?
      lab_results = get_global_property_value("vitals") rescue nil
      if lab_results.nil?
        lab_results = GlobalProperty.new
        lab_results.property = "vitals"
        lab_results.property_value = params[:vitals].join(";")
        lab_results.save
      else
        lab_results = GlobalProperty.find_by_property("vitals")
        lab_results.property_value = params[:vitals].join(";")
        lab_results.save
      end
			redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
		end
	end

  def clinic_days
     if request.post?
      ['peads','all'].each do | age_group |
        if age_group == 'peads'
          clinic_days = GlobalProperty.find_by_property('peads.clinic.days')
          weekdays = params[:peadswkdays]
        else
          clinic_days = GlobalProperty.find_by_property('clinic.days')
          weekdays = params[:weekdays]
        end

        if clinic_days.blank?
          clinic_days = GlobalProperty.new()
          clinic_days.property = 'clinic.days'
          clinic_days.property = 'peads.clinic.days' if age_group == 'peads'
          clinic_days.description = 'Week days when the clinic is open'
        end
        weekdays = weekdays.split(',').collect{ |wd|wd.capitalize }
        clinic_days.property_value = weekdays.join(',')
        clinic_days.save
      end
      flash[:notice] = "Week day(s) successfully created."
      redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}" and return
    end
    @peads_clinic_days = CoreService.get_global_property_value('peads.clinic.days') rescue nil
    @clinic_days = CoreService.get_global_property_value('clinic.days') rescue nil
    render :layout => "menu"
  end

	def lab_results
	  if request.post?
      lab_results = get_global_property_value("lab_results") rescue nil
      if lab_results.nil?
        lab_results = GlobalProperty.new
        lab_results.property = "lab_results"
        lab_results.property_value = params[:test_type_values].join(";")
        lab_results.save
      else
        lab_results = GlobalProperty.find_by_property("lab_results")
        lab_results.property_value = params[:test_type_values].join(";")
        lab_results.save
      end
			redirect_to "/clinic?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}"
		end	
	end
	
	def site_properties
    @link = get_global_property_value("user.management.url").to_s rescue nil

    if @link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end

    @host = request.host_with_port rescue ""

    render :layout => false
	end

  def my_account

    @link = get_global_property_value("user.management.url").to_s rescue nil

    if @link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end
    
    @host = request.host_with_port rescue ""

    render :layout => false
  end

  def overview
    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    @encounter_activities = UserProperty.find(:first, :conditions => ["property = '#{@project}.activities' AND user_id = ?", @user['user_id']]).property_value.split(",") rescue []
		@encounter_activities.push("APPOINTMENT")
		@to_date = Clinic.overview(@encounter_activities)
		@current_year = Clinic.overview_this_year(@encounter_activities)
		@today = Clinic.overview_today(@encounter_activities)
		@me = Clinic.overview_me(@encounter_activities, @user['user_id'])

    render :layout => false
  end

  def reports
    render :layout => false
  end

  def project_users
    render :layout => false
  end

  def project_users_list
    users = User.find(:all, :conditions => ["username LIKE ? AND user_id IN (?)", "#{params[:username]}%",
        UserProperty.find(:all, :conditions => ["property = 'Status' AND property_value = 'ACTIVE'"]
        ).map{|user| user.user_id}], :limit => 50)

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    result = users.collect { |user|
      [
        user.id,
        (user.user_properties.find_by_property("#{@project}.activities").property_value.split(",") rescue nil),
        (user.user_properties.find_by_property("Last Name").property_value rescue nil),
        (user.user_properties.find_by_property("First Name").property_value rescue nil),
        user.username
      ]
    }

    render :text => result.to_json
  end

  def add_to_project

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless params[:target].nil? || @project.nil?
      user = User.find(params[:target]) rescue nil

      unless user.nil?
        UserProperty.create(
          :user_id => user.id,
          :property => "#{@project}.activities",
          :property_value => ""
        )
      end
    end
    
    redirect_to "/project_users_list" and return
  end

  def remove_from_project

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless params[:target].nil? || @project.nil?
      user = User.find(params[:target]) rescue nil

      unless user.nil?
        user.user_properties.find_by_property("#{@project}.activities").delete
      end
    end
    
    redirect_to "/project_users_list" and return
  end

  def manage_activities

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil?
      @users = UserProperty.find_all_by_property("#{@project}.activities").collect { |user| user.user_id }
    
      @roles = UserRole.find(:all, :conditions => ["user_id IN (?)", @users]).collect { |role| role.role }.sort.uniq

    end

  end

  def check_role_activities
    activities = {}

    if File.exists?("#{Rails.root}/config/protocol_task_flow.yml")
      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["clinical.encounters.sequential.list"].split(",").each{|activity|
        
        activities[activity.titleize] = 0

      } rescue nil
    end
      
    role = params[:role].downcase.gsub(/\s/,".") rescue nil

    unless File.exists?("#{Rails.root}/config/roles")
      Dir.mkdir("#{Rails.root}/config/roles")
    end

    unless role.nil?
      if File.exists?("#{Rails.root}/config/roles/#{role}.yml")
        YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").compact.each{|activity|

          activities[activity.titleize] = 1

        } rescue nil
      end
    end

    render :text => activities.to_json
  end

  def create_role_activities
    activities = []
    
    role = params[:role].downcase.gsub(/\s/,".") rescue nil
    activity = params[:activity] rescue nil

    unless File.exists?("#{Rails.root}/config/roles")
      Dir.mkdir("#{Rails.root}/config/roles")
    end

    unless role.nil? || activity.nil?

      file = "#{Rails.root}/config/roles/#{role}.yml"

      activities = YAML.load_file(file)["#{Rails.env
        }"]["activities.list"].split(",") rescue []

      activities << activity

      activities = activities.map{|a| a.upcase}.uniq

      f = File.open(file, "w")

      f.write("#{Rails.env}:\n    activities.list: #{activities.uniq.join(",")}")

      f.close

    end
    
    activities = {}

    if File.exists?("#{Rails.root}/config/protocol_task_flow.yml")
      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["clinical.encounters.sequential.list"].split(",").each{|activity|

        activities[activity.titleize] = 0

      } rescue nil
    end

    YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").each{|activity|

      activities[activity.titleize] = 1

    } rescue nil

    render :text => activities.to_json
  end

  def remove_role_activities
    activities = []

    role = params[:role].downcase.gsub(/\s/,".") rescue nil
    activity = params[:activity] rescue nil

    unless File.exists?("#{Rails.root}/config/roles")
      Dir.mkdir("#{Rails.root}/config/roles")
    end

    unless role.nil? || activity.nil?

      file = "#{Rails.root}/config/roles/#{role}.yml"

      activities = YAML.load_file(file)["#{Rails.env
        }"]["activities.list"].split(",").map{|a| a.upcase} rescue []

      activities = activities - [activity.upcase]

      activities = activities.map{|a| a.titleize}.uniq

      f = File.open(file, "w")

      f.write("#{Rails.env}:\n    activities.list: #{activities.uniq.join(",")}")

      f.close

    end

    activities = {}

    if File.exists?("#{Rails.root}/config/protocol_task_flow.yml")
      YAML.load_file("#{Rails.root}/config/protocol_task_flow.yml")["#{Rails.env
        }"]["clinical.encounters.sequential.list"].split(",").each{|activity|

        activities[activity.titleize] = 0

      } rescue nil
    end

    YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").each{|activity|

      activities[activity.titleize] = 1

    } rescue nil

    render :text => activities.to_json
  end

  def demographics_fields
    
  end

  def project_members    
  end

  def my_activities    
  end

  def check_user_activities
    activities = {}

    @user["roles"].each do |role|

      role = role.downcase.gsub(/\s/,".") rescue nil

      if File.exists?("#{Rails.root}/config/roles/#{role}.yml")

        YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").each{|activity|

          activities[activity.titleize] = 0 if activity.downcase.match("^" +
              (!params[:search].nil? ? params[:search].downcase : ""))

        } rescue nil

      end
    
    end

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil?
      
      UserProperty.find_by_user_id_and_property(@user["user_id"],
        "#{@project}.activities").property_value.split(",").each{|activity|
        
        activities[activity.titleize] = 1 if activity.downcase.match("^" +
            (!params[:search].nil? ? params[:search].downcase : "")) and !activities[activity.titleize].nil?

      }

    end
    
    render :text => activities.to_json
  end

  def create_user_activity

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil? || params[:activity].nil?

      user = UserProperty.find_by_user_id_and_property(@user["user_id"],
        "#{@project}.activities")

      unless user.nil?
        properties = user.property_value.split(",")

        properties << params[:activity]

        properties = properties.map{|p| p.upcase}.uniq

        user.update_attribute("property_value", properties.join(","))

      else

        UserProperty.create(
          :user_id => @user["user_id"],
          :property => "#{@project}.activities",
          :property_value => params[:activity]
        )

      end

    end
    
    activities = {}

    @user["roles"].each do |role|

      role = role.downcase.gsub(/\s/,".") rescue nil

      if File.exists?("#{Rails.root}/config/roles/#{role}.yml")

        YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").each{|activity|

          activities[activity.titleize] = 0 if activity.downcase.match("^" +
              (!params[:search].nil? ? params[:search].downcase : ""))

        } rescue nil

      end

    end

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil?

      UserProperty.find_by_user_id_and_property(@user["user_id"],
        "#{@project}.activities").property_value.split(",").each{|activity|

        activities[activity.titleize] = 1

      }

    end

    render :text => activities.to_json
  end

  def remove_user_activity

    @project = get_global_property_value("project.name").downcase.gsub(/\s/, ".") rescue nil

    unless @project.nil? || params[:activity].nil?

      user = UserProperty.find_by_user_id_and_property(@user["user_id"],
        "#{@project}.activities")

      unless user.nil?
        properties = user.property_value.split(",").map{|p| p.upcase}.uniq

        properties = properties - [params[:activity].upcase]

        user.update_attribute("property_value", properties.join(","))
      end

    end

    activities = {}

    @user["roles"].each do |role|

      role = role.downcase.gsub(/\s/,".") rescue nil

      if File.exists?("#{Rails.root}/config/roles/#{role}.yml")

        YAML.load_file("#{Rails.root}/config/roles/#{role}.yml")["#{Rails.env
        }"]["activities.list"].split(",").each{|activity|

          activities[activity.titleize] = 0 if activity.downcase.match("^" +
              (!params[:search].nil? ? params[:search].downcase : ""))

        } rescue nil

      end

    end

    unless @project.nil?

      UserProperty.find_by_user_id_and_property(@user["user_id"],
        "#{@project}.activities").property_value.split(",").each{|activity|

        activities[activity.titleize] = 1

      }

    end

    render :text => activities.to_json
  end
  
  def show_selected_fields
    fields = ["Middle Name", "Maiden Name", "Home of Origin", "Current District",
      "Current T/A", "Current Village", "Landmark or Plot", "Cell Phone Number",
      "Office Phone Number", "Home Phone Number", "Occupation", "Nationality"]

    selected = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env
        }"]["demographic.fields"].split(",") rescue []

    @fields = {}

    fields.each{|field|
      if selected.include?(field)
        @fields[field] = 1
      else
        @fields[field] = 0
      end
    }
    
    render :text => @fields.to_json
  end

  def remove_field
    initial = YAML.load_file("#{Rails.root}/config/application.yml").to_hash rescue {}

    demographics = initial["#{Rails.env}"]["demographic.fields"].split(",") rescue []

    demographics = demographics - [params[:target]]

    initial["#{Rails.env}"]["demographic.fields"] = demographics.join(",")

    File.open("#{Rails.root}/config/application.yml", "w+") { |f| f.write(initial.to_yaml) }

    fields = ["Middle Name", "Maiden Name", "Home of Origin", "Current District",
      "Current T/A", "Current Village", "Landmark or Plot", "Cell Phone Number",
      "Office Phone Number", "Home Phone Number", "Occupation", "Nationality"]

    selected = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env
        }"]["demographic.fields"].split(",") rescue []

    @fields = {}

    fields.each{|field|
      if selected.include?(field)
        @fields[field] = 1
      else
        @fields[field] = 0
      end
    }

    render :text => @fields.to_json
  end

  def add_field
    initial = YAML.load_file("#{Rails.root}/config/application.yml").to_hash rescue {}

    demographics = initial["#{Rails.env}"]["demographic.fields"].split(",") rescue []

    demographics = demographics + [params[:target]]

    initial["#{Rails.env}"]["demographic.fields"] = demographics.join(",")

    File.open("#{Rails.root}/config/application.yml", "w+") { |f| f.write(initial.to_yaml) }

    fields = ["Middle Name", "Maiden Name", "Home of Origin", "Current District",
      "Current T/A", "Current Village", "Landmark or Plot", "Cell Phone Number",
      "Office Phone Number", "Home Phone Number", "Occupation", "Nationality"]

    selected = YAML.load_file("#{Rails.root}/config/application.yml")["#{Rails.env
        }"]["demographic.fields"].split(",") rescue []

    @fields = {}

    fields.each{|field|
      if selected.include?(field)
        @fields[field] = 1
      else
        @fields[field] = 0
      end
    }

    render :text => @fields.to_json
  end

end