class LocationController < ApplicationController
		def locations
		search_string = (params[:search_string] || 'neno').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		locations =  Location.find(:all, :select =>'name', :conditions => ["name LIKE ?", '%' + search_string + '%'])
		render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
	end

end
