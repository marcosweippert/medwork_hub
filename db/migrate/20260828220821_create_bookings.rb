class CreateBookings < ActiveRecord::Migration[7.1]
  def change
    create_table :bookings do |t|
      t.references :professional, null: false, foreign_key: true
      t.references :room, null: false, foreign_key: true
      t.datetime :start_time
      t.datetime :end_time
      t.string :status

      t.timestamps
    end
  end
end
