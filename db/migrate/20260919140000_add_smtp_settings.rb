class AddSmtpSettings < ActiveRecord::Migration[7.1]
  def up
    change_table :settings, bulk: true do |t|
      t.string :smtp_address
      t.integer :smtp_port
      t.string :smtp_domain
      t.string :smtp_username
      t.string :smtp_password
      t.string :smtp_authentication
      t.boolean :smtp_enable_starttls, default: true, null: false
      t.string :mailer_from
      t.string :mailer_host
      t.integer :mailer_port
      t.string :mailer_protocol
    end

    Setting.reset_column_information
    setting = Setting.order(:id).first
    return unless setting

    setting.update_columns(
      smtp_address: ENV["SMTP_ADDRESS"].presence,
      smtp_port: ENV["SMTP_PORT"].presence&.to_i,
      smtp_domain: ENV["SMTP_DOMAIN"].presence,
      smtp_username: ENV["SMTP_USERNAME"].presence,
      smtp_password: ENV["SMTP_PASSWORD"].to_s.gsub(/\s+/, "").presence,
      smtp_authentication: ENV["SMTP_AUTHENTICATION"].presence || "plain",
      smtp_enable_starttls: ENV["SMTP_ENABLE_STARTTLS_AUTO"].to_s != "false",
      mailer_from: ENV["MAILER_FROM"].presence,
      mailer_host: ENV["MAILER_HOST"].presence,
      mailer_port: ENV["MAILER_PORT"].presence&.to_i,
      mailer_protocol: ENV["MAILER_PROTOCOL"].presence,
      updated_at: Time.current
    )
  end

  def down
    remove_columns :settings, :smtp_address, :smtp_port, :smtp_domain, :smtp_username,
                   :smtp_password, :smtp_authentication, :smtp_enable_starttls,
                   :mailer_from, :mailer_host, :mailer_port, :mailer_protocol
  end
end
