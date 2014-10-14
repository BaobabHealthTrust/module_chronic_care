
class User < ActiveRecord::Base
	
	set_table_name :users
	set_primary_key :user_id
	include Openmrs

	has_many :user_properties, :foreign_key => :user_id # no default scope
  has_many :user_roles, :foreign_key => :user_id, :dependent => :delete_all # no default scope

  cattr_accessor :current

  def admin?
		admin = user_roles.map{|user_role| user_role.role }.include? 'Informatics Manager'
		admin = user_roles.map{|user_role| user_role.role }.include? 'System Developer' unless admin
		admin = user_roles.map{|user_role| user_role.role }.include? 'Superuser' unless admin
		admin
	end
  
end
