# SMTP is configured from Settings (admin UI), then ENV, then credentials.
# Development writes files to tmp/mail unless an SMTP address is set.
class MailerConfig
  SETTING_KEYS = {
    "SMTP_ADDRESS" => :smtp_address,
    "SMTP_PORT" => :smtp_port,
    "SMTP_DOMAIN" => :smtp_domain,
    "SMTP_USERNAME" => :smtp_username,
    "SMTP_PASSWORD" => :smtp_password,
    "SMTP_AUTHENTICATION" => :smtp_authentication,
    "SMTP_ENABLE_STARTTLS_AUTO" => :smtp_enable_starttls,
    "MAILER_FROM" => :mailer_from,
    "MAILER_HOST" => :mailer_host,
    "MAILER_PORT" => :mailer_port,
    "MAILER_PROTOCOL" => :mailer_protocol
  }.freeze

  class << self
    def apply!(config)
      config.action_mailer.delivery_method = delivery_method
      config.action_mailer.perform_deliveries = true
      config.action_mailer.raise_delivery_errors = raise_errors?
      config.action_mailer.default_url_options = url_options
      config.action_mailer.asset_host = asset_host

      case delivery_method
      when :smtp
        config.action_mailer.smtp_settings = smtp_settings
      when :file
        config.action_mailer.file_settings = { location: Rails.root.join("tmp/mail") }
      end
    end

    def reload!
      apply!(Rails.application.config)
      ActionMailer::Base.delivery_method = delivery_method
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.raise_delivery_errors = raise_errors?
      ActionMailer::Base.default_url_options = url_options
      ActionMailer::Base.smtp_settings = smtp_settings if delivery_method == :smtp
    end

    def delivery_method
      return :test if Rails.env.test?
      return :smtp if smtp_configured?
      return :file if Rails.env.development?

      :smtp
    end

    def smtp_configured?
      address.present?
    end

    def from_address
      env(:MAILER_FROM).presence || clinic_from.presence || "medwork@localhost"
    end

    def address
      env(:SMTP_ADDRESS)
    end

    def port
      (env(:SMTP_PORT).presence || 587).to_i
    end

    def domain
      env(:SMTP_DOMAIN).presence || url_options[:host]
    end

    def username
      env(:SMTP_USERNAME)
    end

    def authentication
      (env(:SMTP_AUTHENTICATION).presence || "plain").to_sym
    end

    def starttls?
      env(:SMTP_ENABLE_STARTTLS_AUTO).to_s != "false"
    end

    def url_options
      opts = { host: env(:MAILER_HOST).presence || default_host }
      port = env(:MAILER_PORT).presence || default_port
      opts[:port] = port.to_i if port.present?
      protocol = env(:MAILER_PROTOCOL).presence || default_protocol
      opts[:protocol] = protocol if protocol.present?
      opts
    end

    def smtp_settings
      settings = {
        address: address,
        port: port,
        domain: domain,
        enable_starttls_auto: starttls?,
        authentication: authentication
      }
      if username.present?
        settings[:user_name] = username
        settings[:password] = password
      end
      settings
    end

    def password_configured?
      password.present?
    end

    def summary
      {
        delivery_method: delivery_method.to_s,
        from: from_address,
        host: url_options[:host],
        smtp_address: address.presence || (delivery_method == :file ? "tmp/mail (file)" : "not set"),
        smtp_port: smtp_configured? ? port : nil,
        smtp_username: username.present? ? username : "—",
        smtp_password: password_configured? ? "saved" : "not set",
        starttls: smtp_configured? ? starttls? : nil,
        protocol: url_options[:protocol]
      }
    end

    private

    def password
      env(:SMTP_PASSWORD).to_s.gsub(/\s+/, "").presence
    end

    def clinic_from
      Setting.current.clinic_email if setting_ready?
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      nil
    end

    def raise_errors?
      smtp_configured? || Rails.env.production? || env(:MAILER_RAISE_ERRORS).to_s == "true"
    end

    def asset_host
      protocol = url_options[:protocol].presence || "http"
      host = url_options[:host]
      port = url_options[:port]
      port_part = port.present? ? ":#{port}" : ""
      "#{protocol}://#{host}#{port_part}"
    end

    def default_host
      "localhost"
    end

    def default_port
      Rails.env.production? ? nil : 3000
    end

    def default_protocol
      Rails.env.production? ? "https" : "http"
    end

    CREDENTIAL_KEYS = {
      "SMTP_ADDRESS" => :address,
      "SMTP_PORT" => :port,
      "SMTP_DOMAIN" => :domain,
      "SMTP_USERNAME" => :user_name,
      "SMTP_PASSWORD" => :password,
      "SMTP_AUTHENTICATION" => :authentication,
      "SMTP_ENABLE_STARTTLS_AUTO" => :enable_starttls_auto,
      "MAILER_FROM" => :from,
      "MAILER_HOST" => :host,
      "MAILER_PORT" => :url_port,
      "MAILER_PROTOCOL" => :protocol,
      "MAILER_RAISE_ERRORS" => :raise_errors
    }.freeze

    def env(key)
      setting_value(key).presence || ENV[key.to_s].presence || smtp_credential(key)
    end

    def setting_value(key)
      return unless setting_ready?

      column = SETTING_KEYS[key.to_s]
      return unless column && Setting.column_names.include?(column.to_s)

      value = Setting.current.public_send(column)
      case value
      when TrueClass, FalseClass then value.to_s
      when Integer then value.to_s
      else value.presence
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      nil
    end

    def setting_ready?
      defined?(Setting) && ActiveRecord::Base.connected? && Setting.table_exists?
    end

    def smtp_credential(key)
      smtp = Rails.application.credentials[:smtp]
      return unless smtp.respond_to?(:[])

      smtp[CREDENTIAL_KEYS[key.to_s]]&.to_s.presence
    rescue ActiveSupport::EncryptedFile::MissingKeyError, Errno::ENOENT
      nil
    end
  end
end
