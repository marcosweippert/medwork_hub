class AddEmailBouncesAndWelcomeTemplate < ActiveRecord::Migration[7.1]
  def change
    add_column :outbound_emails, :message_id, :string
    add_column :outbound_emails, :bounced_at, :datetime
    add_index :outbound_emails, :message_id

    add_column :settings, :welcome_email_subject, :string
    add_column :settings, :welcome_email_html, :text

    reversible do |dir|
      dir.up do
        Setting.reset_column_information
        Setting.find_each do |setting|
          setting.update_columns(
            welcome_email_subject: WelcomeEmailTemplate::DEFAULT_SUBJECT,
            welcome_email_html: WelcomeEmailTemplate::DEFAULT_HTML
          )
        end
      end
    end
  end
end
