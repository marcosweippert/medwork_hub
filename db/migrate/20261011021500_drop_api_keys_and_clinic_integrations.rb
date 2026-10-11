class DropApiKeysAndClinicIntegrations < ActiveRecord::Migration[7.1]
  def change
    drop_table :api_keys
    drop_table :clinic_integrations
  end
end
