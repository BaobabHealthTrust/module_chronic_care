class OpenmrsPerson < ActiveRecord::Base
  set_primary_key :person_id
  set_table_name :person
  has_many :openmrs_person_names, :foreign_key => :person_id

  #require 'uuidtools'
  def before_save
    self.uuid = UUIDTools::UUID.random_create.to_s
    self.date_created = Time.now
  end

  def self.get_authorisers

    name = CoreUserRole.find(:all, :conditions => ["role_id = ?", CoreRole.find_by_role('Administrator').id])

    names = name.map{|x| [x.user.openmrs_person.openmrs_person_names.last.given_name + " " + x.user.openmrs_person.openmrs_person_names.last.family_name, x.user.id]}

  end


end
