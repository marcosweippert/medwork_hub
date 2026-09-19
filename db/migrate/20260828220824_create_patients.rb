class CreatePatients < ActiveRecord::Migration[7.1]
  def change
    create_table :patients do |t|
      t.references :professional, null: false, foreign_key: true
      t.string :name
      t.string :contact
      t.text :history

      t.timestamps
    end
  end
end
