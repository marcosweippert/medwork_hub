class AddMustChangePasswordAndDropPlans < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :must_change_password, :boolean, default: false, null: false
    drop_table :subscriptions, if_exists: true
    drop_table :plans, if_exists: true
  end
end
