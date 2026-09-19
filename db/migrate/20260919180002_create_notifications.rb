class CreateNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :notifiable, polymorphic: true, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body
      t.datetime :read_at
      t.timestamps
    end

    add_index :notifications, %i[user_id read_at]
    add_index :notifications, %i[user_id created_at]
  end
end
