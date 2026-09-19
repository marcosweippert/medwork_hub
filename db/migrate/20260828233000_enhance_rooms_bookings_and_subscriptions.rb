class EnhanceRoomsBookingsAndSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :rooms, :daily_rate, :decimal, precision: 10, scale: 2, default: 0
    add_column :rooms, :monthly_rate, :decimal, precision: 10, scale: 2, default: 0
    add_column :rooms, :hourly_rate, :decimal, precision: 10, scale: 2
    add_column :rooms, :opens_at, :integer, default: 8
    add_column :rooms, :closes_at, :integer, default: 18

    add_reference :bookings, :invoice, foreign_key: true
    add_column :bookings, :amount, :decimal, precision: 10, scale: 2
    add_column :bookings, :billing_type, :string

    add_reference :invoices, :room, foreign_key: true
    add_column :invoices, :notes, :text
    add_column :invoices, :paid_at, :datetime

    create_table :subscriptions do |t|
      t.references :professional, null: false, foreign_key: true
      t.references :plan, null: false, foreign_key: true
      t.references :room, foreign_key: true
      t.date :starts_on
      t.date :ends_on
      t.string :status, default: "active"
      t.timestamps
    end
  end
end
