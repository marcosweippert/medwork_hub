class CreateSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :settings do |t|
      t.string :clinic_name, default: "MedWork Hub", null: false
      t.string :clinic_email
      t.string :clinic_phone
      t.string :currency, default: "BRL", null: false
      t.integer :slot_minutes, default: 30, null: false
      t.integer :saturday_opens_at, default: 9, null: false
      t.integer :saturday_closes_at, default: 12, null: false
      t.boolean :sunday_closed, default: true, null: false
      t.integer :free_cancel_hours, default: 24, null: false
      t.integer :late_cancel_percent, default: 50, null: false
      t.integer :started_cancel_percent, default: 100, null: false
      t.string :week_starts_on, default: "sunday", null: false
      t.timestamps
    end
  end
end
