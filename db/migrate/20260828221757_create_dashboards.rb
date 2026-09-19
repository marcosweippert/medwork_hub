class CreateDashboards < ActiveRecord::Migration[7.1]
  def change
    create_table :dashboards do |t|
      t.string :name
      t.text :description
      t.string :layout

      t.timestamps
    end
  end
end
