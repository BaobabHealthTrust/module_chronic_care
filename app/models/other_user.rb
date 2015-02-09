require 'digest/sha1'
require 'digest/sha2'

class OtherUser < ActiveRecord::Base
  set_table_name :users
	set_primary_key :user_id
  cattr_accessor :current
  has_one :core_user_role
  belongs_to :openmrs_person, :foreign_key => :person_id

  has_many :user_properties, :class_name => "OpenmrsUserProperty", :foreign_key => :user_id
  has_many :user_roles, :class_name => "OpenmrsUserRole", :foreign_key => :user_id, :dependent => :delete_all

  #require 'uuidtools'

  before_save :encrypt_password

  def first_name
    person_demo = OpenmrsPersonName.find_by_person_id(self.get_person)
    person_demo.first_name rescue ""
  end

  def last_name
    person_demo = OpenmrsPersonName.find_by_person_id(self.get_person)
    person_demo.last_name rescue ""
  end

  def gender
    person_demo = OpenmrsPersonName.find_by_person_id(self.get_person)
    person_demo.gender rescue ""
  end

  def name
    person_demo = OpenmrsPersonName.find_by_person_id(self.get_person)
    person_demo.given_name + " " + person_demo.family_name rescue ""
    # CorePerson.find(self.user_id).name
  end

  def get_person
    OtherUser.find(self.id).person_id
  end

  def status
    OpenmrsUserProperty.find_by_property("Status", :conditions => ["user_id = ?", self.id]) rescue nil
  end

  def status_value
    self.status.property_value rescue nil
  end

  def self.check_authenticity(password, username)
    user = OtherUser.find_by_username(username)
    if !user.blank?
      if user.password == user.verify_password(password, user.salt)
        return user
      end
    end
    return nil
  end

  def verify_password(in_password, in_salt)
    new_salt = salt = Digest::SHA1.hexdigest(in_password + in_salt)
  end

  def encrypt_password
    self.salt = OtherUser.random_string(10)
    self.password = encrypt(self.password, self.salt)
    self.uuid = UUIDTools::UUID.random_create.to_s
    self.date_created = Time.now
    self.creator = OtherUser.current.id
  end

  def encrypt(password,salt)
    Digest::SHA1.hexdigest(password+salt)
  end

  def self.random_string(len)
    #generate a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end

  def other_demographics
    {
      :user_id => self.id,
      :name => self.name,
      :token => (self.user_properties.find_by_property("Token").property_value rescue nil),
      :roles => (self.user_roles.collect{|r| r.role} rescue []),
      :status => self.status_value
    }
  end

end

