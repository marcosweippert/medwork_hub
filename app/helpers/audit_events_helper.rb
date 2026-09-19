module AuditEventsHelper
  def audit_action_title(event)
    verb = t("audit.verbs.#{event.verb}", default: event.verb.to_s.humanize)
    resource = t("audit.resources.#{event.resource_key}", default: event.auditable_type.presence || event.resource_key.to_s.humanize)
    t("audit.action_title", verb: verb, resource: resource)
  end

  def audit_resource_label(event)
    t("audit.resources.#{event.resource_key}", default: event.auditable_type.presence || "—")
  end

  def audit_field_label(field)
    t("audit.fields.#{field}", default: field.to_s.humanize)
  end

  def format_audit_value(value)
    case value
    when nil, "" then "—"
    when true, "true" then t("ui.yes")
    when false, "false" then t("ui.no")
    when Array then value.map { |item| format_audit_value(item) }.join(", ")
    when Hash then value.map { |key, item| "#{key}: #{format_audit_value(item)}" }.join(", ")
    else
      value.to_s.truncate(160)
    end
  end

  def audit_filter_params
    params.permit(:q, :action_name, :record_type, :user_id, :from, :to, :verb).to_h
  end
end
