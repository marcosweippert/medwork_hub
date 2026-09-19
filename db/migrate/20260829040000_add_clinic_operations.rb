class AddClinicOperations < ActiveRecord::Migration[7.1]
  def change
    add_column :bookings, :recurrence_group_id, :string
    add_column :bookings, :reminder_sent_at, :datetime
    add_column :bookings, :patient_id, :bigint
    add_index :bookings, :recurrence_group_id
    add_index :bookings, :patient_id
    add_foreign_key :bookings, :patients

    add_column :invoices, :reminder_sent_at, :datetime
    add_column :invoices, :pix_txid, :string
    add_index :invoices, :pix_txid, unique: true

    add_column :settings, :pix_key, :string
    add_column :settings, :pix_name, :string
    add_column :settings, :pix_city, :string
    add_column :settings, :whatsapp_phone, :string

    add_column :professionals, :phone, :string

    create_table :waitlist_entries do |t|
      t.references :room, null: false, foreign_key: true
      t.references :professional, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, default: "waiting", null: false
      t.datetime :notified_at
      t.timestamps
    end
    add_index :waitlist_entries, %i[room_id professional_id starts_at], name: "index_waitlist_unique_waiting", unique: true, where: "status = 'waiting'"

    create_table :room_blocks do |t|
      t.references :room, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :reason
      t.timestamps
    end
    add_index :room_blocks, %i[room_id starts_at ends_at]

    create_table :appointment_notes do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end

    create_table :audit_events do |t|
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.text :details
      t.timestamps
    end
    add_index :audit_events, %i[auditable_type auditable_id]
  end
end
