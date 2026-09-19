class AddConfigToClinicIntegrations < ActiveRecord::Migration[7.1]
  def change
    add_column :clinic_integrations, :config, :jsonb, default: {}, null: false
  end
end
