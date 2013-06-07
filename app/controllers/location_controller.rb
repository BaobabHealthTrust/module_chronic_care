class LocationController < ApplicationController
	def locations
		#raise params[:category]
		search_string = (params[:search_string] || 'neno').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		locations =  Location.find(:all, :select =>'name', :conditions => ["name LIKE ?", '%' + search_string + '%'], :limit => 10)
		render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
	end

	def secondary_locations
		search_string = (params[:search_string] || 'neno').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		locations =  Location.find(:all, :select =>'name', :conditions => ["name LIKE ? AND description LIKE '%district hospital%'", '%' + search_string + '%'], :limit => 10)
		render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
	end

	def tertialy_locations
		search_string = (params[:search_string] || 'neno').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		locations =  Location.find(:all, :select =>'name', :conditions => ["name LIKE ? AND description LIKE '%arv code%'", '%' + search_string + '%'], :limit => 10)
		render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
	end

end
