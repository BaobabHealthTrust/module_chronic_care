class OpenmrsUserRole < ActiveRecord::Base
  set_table_name :user_role
  set_primary_keys :role, :user_id

  include Openmrs
  belongs_to :user, :class_name => 'OtherUser', :foreign_key => :user_id

  def self.distinct_roles
    OpenmrsUserRole.find(:all, :select => "DISTINCT role")
  end
end