class CreateRooms < ActiveRecord::Migration[7.1]
  def change
    create_table :rooms do |t|
      t.string :name
      t.integer :capacity
      t.text :equipment

      t.timestamps
    end
  end
end
