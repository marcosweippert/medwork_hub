class ClinicIntegration < ApplicationRecord
  include Auditable

  CATALOG = {
    "smtp" => { builtin: true, settings: "mail" },
    "pix" => { builtin: true, settings: "pix" },
    "whatsapp" => { builtin: true, settings: "pix" },
    "calendar" => { builtin: true, required: true },
    "n8n" => { webhook: true, api: true },
    "webhooks" => { webhook: true },
    "custom" => { webhook: true, repeatable: true },
    "zapier" => { webhook: true },
    "make" => { webhook: true },
    "slack" => { webhook: true },
    "discord" => { webhook: true },
    "telegram" => { webhook: true },
    "microsoft_teams" => { webhook: true },
    "google_sheets" => { webhook: true },
    "notion" => { webhook: true },
    "twilio" => { webhook: true },
    "google_calendar" => {},
    "outlook" => {}
  }.freeze

  BUILTIN_KINDS = CATALOG.select { |_, meta| meta[:builtin] }.keys.freeze
  HUB_EVENTS = %w[booking.created invoice.paid ticket.created n8n.test].freeze

  before_validation :assign_defaults, on: :create

  validates :provider, presence: true, uniqueness: { case_sensitive: false }
  validates :kind, presence: true, inclusion: { in: CATALOG.keys }
  validates :name, presence: true

  scope :installed, -> { order(:id) }
  scope :webhook_targets, -> {
    where(enabled: true).where("coalesce(config->>'webhook_url', '') <> ''")
  }

  def self.ensure_catalog!
    BUILTIN_KINDS.each do |kind|
      rec = find_or_initialize_by(provider: kind)
      rec.kind = kind
      rec.name = rec.name.presence || default_name_for(kind)
      rec.save!
    end
    installed
  end

  def self.n8n
    find_by(kind: "n8n") || find_by(provider: "n8n")
  end

  def self.available_kinds
    installed = where.not(kind: "custom").distinct.pluck(:kind)
    CATALOG.keys - ["custom"] - installed
  end

  def self.default_name_for(kind)
    I18n.t("integrations.providers.#{kind}.name", default: kind.to_s.humanize)
  end

  def to_param
    provider
  end

  def catalog
    CATALOG.fetch(kind) { CATALOG.fetch("custom") }
  end

  def display_name
    name.presence || self.class.default_name_for(kind)
  end

  def description
    notes.presence || I18n.t("integrations.providers.#{kind}.body", default: "")
  end

  def help_text
    I18n.t("integrations.providers.#{kind}.help", default: "")
  end

  def builtin?
    catalog[:builtin]
  end

  def required?
    catalog[:required]
  end

  def form?
    webhook? || api?
  end

  def webhook?
    catalog[:webhook]
  end

  def api?
    catalog[:api]
  end

  def repeatable?
    catalog[:repeatable]
  end

  def deletable?
    !builtin?
  end

  def settings_key
    catalog[:settings]
  end

  def connected?
    case kind
    when "smtp"
      setting = Setting.current
      setting.smtp_address.present? || setting.smtp_password_set?
    when "pix"
      Setting.current.pix_configured?
    when "whatsapp"
      Setting.current.whatsapp_phone.present?
    when "calendar"
      true
    else
      return enabled? && webhook_url.present? if webhook?
      enabled?
    end
  end

  def connect!
    update!(enabled: true, connected_at: connected_at || Time.current)
  end

  def disconnect!
    update!(enabled: false)
  end

  def config_hash
    (config.presence || {}).stringify_keys
  end
  alias_method :n8n_config, :config_hash

  def webhook_url
    config_hash["webhook_url"].to_s.strip
  end

  def webhook_url=(value)
    merge_config("webhook_url", value.to_s.strip)
  end

  def api_base_url
    config_hash["api_base_url"].to_s.strip.chomp("/")
  end

  def api_base_url=(value)
    merge_config("api_base_url", value.to_s.strip.chomp("/"))
  end

  def api_token
    config_hash["api_token"].to_s.strip
  end

  def api_token=(value)
    token = value.to_s.strip
    return if token.blank?

    merge_config("api_token", token)
  end

  def channel
    config_hash["channel"].to_s.strip
  end

  def channel=(value)
    merge_config("channel", value.to_s.strip)
  end

  def api_token_set?
    api_token.present?
  end

  def assign_n8n_config(attrs)
    self.webhook_url = attrs[:webhook_url]
    self.api_base_url = attrs[:api_base_url]
    self.api_token = attrs[:api_token]
  end

  def audit_details
    changes = previous_changes.except("updated_at", "created_at")
    if changes.key?("config")
      changes["config"] = {
        "webhook_url" => webhook_url.present?,
        "api_base_url" => api_base_url,
        "channel" => channel,
        "api_token" => api_token_set?
      }
    end
    changes.presence || { "id" => id, "provider" => provider, "kind" => kind, "name" => name }
  end

  private

  def assign_defaults
    self.kind = kind.to_s.presence || "custom"
    self.name = name.to_s.strip.presence || self.class.default_name_for(kind)
    self.provider = provider.to_s.strip.presence || build_provider
  end

  def build_provider
    return kind unless repeatable?

    base = "custom-#{name.to_s.parameterize.presence || 'app'}"
    candidate = base
    suffix = 2
    while self.class.exists?(provider: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    candidate
  end

  def merge_config(key, value)
    cfg = config_hash
    cfg[key] = value
    self.config = cfg
  end
end
