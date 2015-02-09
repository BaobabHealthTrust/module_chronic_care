class OpenmrsPersonName < ActiveRecord::Base
  set_primary_key :person_name_id
  set_table_name :person_name
  belongs_to :openmrs_person, :foreign_key => :person_id

  #require 'uuidtools'
  before_save :set_uuid

  def set_uuid
    self.uuid = UUIDTools::UUID.random_create.to_s
    self.date_created = Time.now
  end

  def full_name
    (self.given_name + " " + self.family_name) rescue " "
  end

end

