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
  validates :ticket_sla_urgent, :ticket_sla_high, :ticket_sla_medium, :ticket_sla_low, :ticket_sla_warn_hours,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 168 }
  validates :ticket_default_priority, inclusion: { in: %w[low medium high urgent] }
  validates :ticket_auto_close_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 365 }
  belongs_to :ticket_default_assignee, class_name: "User", optional: true
  has_one_attached :logo
  validate :saturday_closes_after_opens
  validate :pix_key_format
  validate :acceptable_logo
  before_validation :normalize_pix_key
  before_validation :normalize_smtp_blanks
  after_commit :reset_current_cache

  def self.current
    ActiveSupport::IsolatedExecutionState[:clinic_setting] ||= order(:id).first || create!(clinic_name: "MedWork Hub")
  end

  def self.reset_current!
    ActiveSupport::IsolatedExecutionState.delete(:clinic_setting)
  end

  def week_start_symbol
    week_starts_on.to_s == "monday" ? :monday : :sunday
  end

  def ticket_sla_hours_for(priority)
    case priority.to_s
    when "urgent" then ticket_sla_urgent.to_i
    when "high" then ticket_sla_high.to_i
    when "low" then ticket_sla_low.to_i
    else ticket_sla_medium.to_i
    end
  end

  def ticket_sla_policy
    I18n.t(
      "tickets.sla_policy",
      urgent: ticket_sla_urgent,
      high: ticket_sla_high,
      medium: ticket_sla_medium,
      low: ticket_sla_low
    )
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

  def acceptable_logo
    return unless logo.attached?

    unless logo.content_type.in?(%w[image/png image/jpeg image/jpg image/webp])
      errors.add(:logo, I18n.t("settings.clinic.logo_invalid"))
    end
    return unless logo.byte_size > 2.megabytes

    errors.add(:logo, I18n.t("settings.clinic.logo_too_large"))
  end

  def reset_current_cache
    self.class.reset_current!
  end
end
