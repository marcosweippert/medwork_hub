class CreateTicketComments < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_comments do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.boolean :internal, null: false, default: false

      t.timestamps
    end
  end
end
