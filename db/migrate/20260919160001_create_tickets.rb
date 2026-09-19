class CreateTickets < ActiveRecord::Migration[7.1]
  def change
    create_table :tickets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :assignee, null: true, foreign_key: { to_table: :users }
      t.string :subject, null: false
      t.text :body, null: false
      t.string :status, null: false, default: "open"
      t.string :priority, null: false, default: "medium"
      t.string :category, null: false, default: "other"
      t.integer :sla_hours
      t.datetime :sla_due_at
      t.datetime :first_response_at
      t.datetime :resolved_at
      t.datetime :closed_at

      t.timestamps
    end

    add_index :tickets, :status
    add_index :tickets, :priority
    add_index :tickets, :sla_due_at
  end
end
