class CreateClinicIntegrations < ActiveRecord::Migration[7.1]
  def change
    create_table :clinic_integrations do |t|
      t.string :provider, null: false
      t.boolean :enabled, default: false, null: false
      t.datetime :connected_at
      t.timestamps
    end

    add_index :clinic_integrations, :provider, unique: true
  end
end
