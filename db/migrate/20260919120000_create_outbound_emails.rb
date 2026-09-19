class CreateOutboundEmails < ActiveRecord::Migration[7.1]
  def change
    create_table :outbound_emails do |t|
      t.string :to_address, null: false
      t.string :cc
      t.string :bcc
      t.string :from_address
      t.string :subject
      t.string :mailer
      t.string :action_name
      t.string :status, null: false, default: "sent"
      t.text :body_html
      t.text :body_text
      t.text :error_message
      t.datetime :sent_at
      t.references :user, foreign_key: true

      t.timestamps
    end

    add_index :outbound_emails, :status
    add_index :outbound_emails, :sent_at
    add_index :outbound_emails, :to_address
  end
end
