class AddDoseToDrugSet < ActiveRecord::Migration
  def self.up
    add_column :drug_set, :dose, :float
  end

  def self.down
    remove_column :drug_set, :dose
  end
end
