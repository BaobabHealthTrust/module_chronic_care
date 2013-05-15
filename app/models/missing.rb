class Missing < ActiveRecord::Base
	require "fastercsv"
	def self.missing_ta
			missing = ["tsabango", "njewa", "kabudula","malili","chitukula","masumbankhunda","chimutu","masula","khongoni"]
			@dis = District.find_by_name("lilongwe city").id	
			missing.each do |current_ta|
				current_root = RAILS_ROOT + '/script/' + current_ta + '.csv'
				current_ta[0] = current_ta.first.capitalize[0]
				puts "Searching for T.A : #{current_ta}"
				begin
      				FasterCSV.foreach("#{current_root}", :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|
					@ta = TraditionalAuthority.first(:conditions  => ['district_id = ? and name = ?', @dis, current_ta])
						if @ta.nil?
							ta = TraditionalAuthority.new
							ta.name = current_ta
							ta.district_id = @dis
							ta.date_created = Time.now
							ta.creator = 1
							ta.save
							@ta = ta.id
							puts "Added new T.A : #{current_ta}"
						else
						@ta = @ta.traditional_authority_id	
						end
						@chief = Village.first(:conditions  => ['traditional_authority_id = ? and name = ?', @ta,row[0]])
						if @chief.nil?
							ta = Village.new
							ta.name = row[0]
							ta.traditional_authority_id = @ta
							ta.date_created = Time.now
							ta.creator = 1
							ta.save
							puts "Added new village : #{row[0]}"
						end
						
					end	
				rescue
					puts "No such file : #{current_root} "
				end
			end
	end
end
