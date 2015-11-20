Source_db= YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['development']["database"]

CONN = ActiveRecord::Base.connection

def start
  epilepsy_pats = Encounter.find_by_sql("select patient_id, DATE(start_date) as start_date from #{Source_db}.patients_on_epilepsy_medication")
  (epilepsy_pats || []).each do |patient|
     #check if patient already have Epilepsy visit encounter = 144
     ep_encounter = Encounter.find_by_sql("SELECT * from #{Source_db}.encounter
                                           where patient_id = #{patient.patient_id}
                                           and encounter_type = 144
                                           and voided = 0").map(&:patient_id)

      if ep_encounter.blank?
        #get min date the patient got epilepsy medication
        ep_min_date = Encounter.find_by_sql("SELECT min(DATE(start_date)) as start_date from #{Source_db}.patients_on_epilepsy_medication
                                             WHERE patient_id = #{patient.patient_id}").first.start_date

        puts"<<<<<<<working on patient: #{patient.patient_id}"
        #create Epilepsy visit encounter
           @enc_date = "#{ep_min_date} 00:00:01"

           ActiveRecord::Base.connection.execute <<EOF
INSERT INTO #{Source_db}.encounter(patient_id, encounter_type,  provider_id, location_id, encounter_datetime, creator, date_created, uuid) VALUES (#{patient.patient_id}, 144, 1, 10, '#{@enc_date}', 1, (NOW()), (SELECT UUID()))
EOF
        puts"<<<<<<<finished working on patient: #{patient.patient_id}"
      end
  end
end
start
