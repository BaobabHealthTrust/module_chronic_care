class PeopleController < GenericPeopleController
	def confirm
		session_date = session[:datetime] || Date.today
		if request.post?
			redirect_to search_complete_url(params[:found_person_id], params[:relation]) and return
		end
		@found_person_id = params[:found_person_id] 
		@relation = params[:relation] rescue nil
		@person = Person.find(@found_person_id) rescue nil
		@task = main_next_task(Location.current_location, @person.patient, session_date.to_date)
		#@arv_number = PatientService.get_patient_identifier(@person, 'ARV Number')
		@patient_bean = PatientService.get_patient(@person)
		render :layout => 'menu'
	end 
end
 
