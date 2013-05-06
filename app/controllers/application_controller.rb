
class ApplicationController < ActionController::Base
  helper :all

  before_filter :check_user, :except => [:user_login, :user_logout, :missing_program, :static_locations,
    :missing_concept, :no_user, :no_patient, :project_users_list, :show_selected_fields, :check_role_activities, :missing_encounter_type]
  
  def get_global_property_value(global_property)
		property_value = Settings[global_property]
		if property_value.nil?
			property_value = GlobalProperty.find(:first, :conditions => {:property => "#{global_property}"}
      ).property_value rescue nil
		end
		return property_value
	end

  def create_from_dde_server
    get_global_property_value('create.from.dde.server').to_s == "true" rescue false
  end

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    @patient_id = patient_id
    render :template => 'print/print', :layout => nil
  end

  protected

  def check_user

    link = get_global_property_value("user.management.url").to_s rescue nil

    if link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end

    @user = JSON.parse(RestClient.get("#{link}/verify/#{(params[:user_id])}")) # rescue {}

    # raise @user.to_yaml

    # Track final destination
    file = "#{File.expand_path("#{Rails.root}/tmp", __FILE__)}/current.path.yml"

    f = File.open(file, "w")

    f.write("#{Rails.env}:\n    current.path: #{request.referrer}")

    f.close

    if @user.empty?
      redirect_to "/user_login?internal=true" and return
    end

    if @user["token"].nil?
      redirect_to "/user_login?internal=true" and return
    end

  end

end
