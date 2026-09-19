module Auditable
  extend ActiveSupport::Concern

  included do
    after_create { record_audit("created") }
    after_update { record_audit("updated") }
    after_destroy { record_audit("deleted") }
  end

  private

  def record_audit(verb)
    AuditEvent.create!(
      user: Current.user,
      action: "#{self.class.name.underscore}.#{verb}",
      auditable: self,
      details: audit_details.to_json
    )
  rescue StandardError
    nil
  end

  def audit_details
    changes = previous_changes.except("updated_at", "created_at")
    changes.presence || { "id" => id }
  end
end
