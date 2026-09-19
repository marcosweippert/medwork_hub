class DropDashboards < ActiveRecord::Migration[7.1]
  def up
    drop_table :dashboards, if_exists: true
  end

  def down
    create_table :dashboards do |t|
      t.string :name
      t.text :description
      t.string :layout
      t.timestamps
    end
  end
end
