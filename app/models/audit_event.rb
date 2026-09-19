class AuditEvent < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  VERBS = %w[created updated deleted].freeze

  scope :newest, -> { order(created_at: :desc) }

  def actor_name
    user&.display_name || "System"
  end

  def verb
    action.to_s.split(".").last
  end

  def record_name
    [auditable_type, auditable_id].compact.join(" #").presence || "—"
  end

  def parsed_details
    JSON.parse(details.to_s)
  rescue JSON::ParserError
    details.present? ? { "raw" => details } : {}
  end

  def summary_line
    changes = parsed_details
    keys = changes.is_a?(Hash) ? changes.keys.first(4) : []
    keys.map(&:to_s).join(", ").presence || action.to_s.tr("._", " ")
  end
end
