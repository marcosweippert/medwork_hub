class AuditEvent < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  VERBS = %w[created updated deleted].freeze
  HIDDEN_FIELDS = %w[
    password password_confirmation encrypted_password password_digest
    reset_password_token remember_token token_digest raw_token smtp_password
  ].freeze

  scope :newest, -> { order(created_at: :desc) }
  scope :with_verb, ->(verb) { verb.present? ? where("action LIKE ?", "%.#{verb}") : all }

  def actor_name
    user&.display_name || I18n.t("audit.system")
  end

  def actor_email
    user&.email
  end

  def verb
    action.to_s.split(".").last
  end

  def resource_key
    action.to_s.split(".").first.presence || auditable_type.to_s.underscore
  end

  def record_name
    [auditable_type, auditable_id].compact.join(" #").presence || "—"
  end

  def record_label
    rec = auditable
    label =
      if rec.respond_to?(:display_name)
        rec.display_name
      elsif rec.respond_to?(:name)
        rec.name
      elsif rec.respond_to?(:subject)
        rec.subject
      elsif rec.respond_to?(:provider)
        rec.provider
      end
    label.presence || record_name
  end

  def parsed_details
    JSON.parse(details.to_s)
  rescue JSON::ParserError
    details.present? ? { "raw" => details } : {}
  end

  def change_entries
    hash = parsed_details
    return [] unless hash.is_a?(Hash)

    hash.filter_map do |field, value|
      key = field.to_s
      next if key.in?(%w[updated_at created_at])

      from, to = normalize_change(value)
      {
        field: key,
        from: redact(key, from),
        to: redact(key, to)
      }
    end
  end

  def changes_summary
    entries = change_entries.reject { |entry| entry[:field] == "id" && blank_change?(entry[:from]) }
    return I18n.t("audit.no_field_changes") if entries.empty?

    entries.first(4).map { |entry| summarize_entry(entry) }.join(" · ")
  end

  def change_count
    change_entries.size
  end

  def summary_line
    changes_summary
  end

  def export_changes
    change_entries.map { |entry| summarize_entry(entry) }.join(" | ")
  end

  private

  def normalize_change(value)
    if value.is_a?(Array) && value.length == 2
      [value[0], value[1]]
    else
      [nil, value]
    end
  end

  def redact(key, value)
    return "••••" if hidden_field?(key) && value.present?

    value
  end

  def hidden_field?(key)
    HIDDEN_FIELDS.include?(key) || key.end_with?("_digest", "_token", "_password")
  end

  def blank_change?(value)
    value.nil? || value == "" || value == []
  end

  def summarize_entry(entry)
    label = I18n.t("audit.fields.#{entry[:field]}", default: entry[:field].humanize)
    from = compact_value(entry[:from])
    to = compact_value(entry[:to])
    if from == "—" || from == to
      "#{label}: #{to}"
    else
      "#{label}: #{from} → #{to}"
    end
  end

  def compact_value(value)
    return "—" if blank_change?(value)
    return I18n.t("ui.yes") if value == true || value.to_s == "true"
    return I18n.t("ui.no") if value == false || value.to_s == "false"

    text = value.is_a?(Array) ? value.join(", ") : value.to_s
    text.truncate(48)
  end
end
