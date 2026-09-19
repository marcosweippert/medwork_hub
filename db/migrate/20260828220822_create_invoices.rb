class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|
      t.references :professional, null: false, foreign_key: true
      t.decimal :amount
      t.string :status
      t.date :due_date

      t.timestamps
    end
  end
end
