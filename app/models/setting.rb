class Setting < ApplicationRecord
  WEEK_STARTS = %w[sunday monday].freeze

  validates :clinic_name, presence: true
  validates :slot_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 120 }
  validates :saturday_opens_at, :saturday_closes_at, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 24 }
  validates :free_cancel_hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :late_cancel_percent, :started_cancel_percent, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :week_starts_on, inclusion: { in: WEEK_STARTS }
  validates :smtp_port, :mailer_port, numericality: { only_integer: true, greater_than: 0 }, allow_blank: true
  validates :smtp_authentication, inclusion: { in: %w[plain login cram_md5] }, allow_blank: true
  validates :pix_name, length: { maximum: 25 }, allow_blank: true
  validates :pix_city, length: { maximum: 15 }, allow_blank: true
  validate :saturday_closes_after_opens
  validate :pix_key_format
  before_validation :normalize_pix_key
  before_validation :normalize_smtp_blanks

  def self.current
    order(:id).first || create!(clinic_name: "MedWork Hub")
  end

  def week_start_symbol
    week_starts_on.to_s == "monday" ? :monday : :sunday
  end

  def pix_configured?
    pix_key.present?
  end

  def smtp_password_set?
    smtp_password.to_s.gsub(/\s+/, "").present?
  end

  def assign_smtp_password(raw)
    cleaned = raw.to_s.gsub(/\s+/, "")
    self.smtp_password = cleaned if cleaned.present?
  end

  def sync_env_file!
    payload = {
      "SMTP_ADDRESS" => smtp_address,
      "SMTP_PORT" => smtp_port,
      "SMTP_DOMAIN" => smtp_domain,
      "SMTP_USERNAME" => smtp_username,
      "SMTP_AUTHENTICATION" => smtp_authentication,
      "SMTP_ENABLE_STARTTLS_AUTO" => smtp_enable_starttls,
      "MAILER_FROM" => mailer_from,
      "MAILER_HOST" => mailer_host,
      "MAILER_PORT" => mailer_port,
      "MAILER_PROTOCOL" => mailer_protocol
    }
    EnvFileSync.write(payload)
  end

  private

  def saturday_closes_after_opens
    return if saturday_opens_at.blank? || saturday_closes_at.blank?
    errors.add(:saturday_closes_at, "must be after opening hour") if saturday_closes_at <= saturday_opens_at
  end

  def normalize_smtp_blanks
    self.smtp_port = nil if smtp_port.blank?
    self.mailer_port = nil if mailer_port.blank?
    self.smtp_authentication = smtp_authentication.to_s.presence
  end

  def normalize_pix_key
    self.pix_key = PixKey.normalize(pix_key) if pix_key.present?
  end

  def pix_key_format
    return if pix_key.blank?
    return if PixKey.valid?(pix_key)

    errors.add(:pix_key, "must be a CPF, CNPJ, email, +55 phone or random key")
  end
end
