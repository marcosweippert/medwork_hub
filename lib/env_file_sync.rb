class EnvFileSync
  KEYS = %w[
    SMTP_ADDRESS SMTP_PORT SMTP_DOMAIN SMTP_USERNAME SMTP_PASSWORD
    SMTP_AUTHENTICATION SMTP_ENABLE_STARTTLS_AUTO
    MAILER_FROM MAILER_HOST MAILER_PORT MAILER_PROTOCOL
  ].freeze

  def self.write(values)
    path = Rails.root.join(".env")
    return unless File.exist?(path)

    content = File.read(path)
    content = "#{content}\n" unless content.end_with?("\n")

    values.stringify_keys.each do |key, value|
      next unless KEYS.include?(key)
      next if value.nil?
      line = "#{key}=#{value}"
      if content.match?(/^#{Regexp.escape(key)}=/m)
        content.gsub!(/^#{Regexp.escape(key)}=.*$/, line)
      else
        content << "#{line}\n"
      end
    end

    File.write(path, content)
  end
end
