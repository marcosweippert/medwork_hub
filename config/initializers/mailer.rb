# frozen_string_literal: true

require Rails.root.join("lib/mailer_config")

unless Rails.env.test?
  MailerConfig.apply!(Rails.application.config)
end

Rails.application.config.to_prepare do
  Devise.mailer_sender = -> { MailerConfig.from_address }
end
