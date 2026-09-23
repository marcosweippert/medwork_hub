class AuditEventsController < ApplicationController
  before_action :require_admin
  before_action :set_event, only: %i[show destroy]

  def index
    @actions = AuditEvent.distinct.order(:action).pluck(:action)
    @record_types = AuditEvent.distinct.order(:auditable_type).pluck(:auditable_type).compact
    @users = User.order(:name, :email)
    @events = paginate(filtered_events.includes(:user, :auditable), per: 30)
  end

  def show; end

  def export
    headers = [
      t("ui.when"),
      t("audit.actor"),
      t("ui.email"),
      t("audit.action"),
      t("ui.status"),
      t("audit.record_type"),
      t("audit.record_id"),
      t("audit.record"),
      t("audit.changes")
    ]
    rows = filtered_events.includes(:user, :auditable).limit(5000).map do |event|
      [
        event.created_at.strftime("%d/%m/%Y %H:%M:%S"),
        event.actor_name,
        event.actor_email,
        helpers.audit_action_title(event),
        t("audit.verbs.#{event.verb}", default: event.verb.to_s.humanize),
        helpers.audit_resource_label(event),
        event.auditable_id,
        event.record_label,
        event.export_changes
      ]
    end

    send_data XlsxExport.build(sheet_name: t("nav.audit"), headers: headers, rows: rows),
              filename: "auditoria-#{Time.zone.today.iso8601}.xlsx",
              type: Mime[:xlsx],
              disposition: "attachment"
  end

  def bulk
    events = AuditEvent.where(id: Array(params[:event_ids]))
    case params[:bulk_action]
    when "delete"
      count = events.count
      events.delete_all
      redirect_to audit_events_path, notice: t("audit.bulk_deleted", count: count)
    else
      redirect_to audit_events_path, alert: t("audit.choose_action")
    end
  end

  def destroy
    @event.destroy
    redirect_to audit_events_path, notice: t("audit.deleted")
  end

  private

  def set_event
    @event = AuditEvent.find(params[:id])
  end

  def filtered_events
    scope = AuditEvent.newest
    scope = scope.where(action: params[:action_name]) if params[:action_name].present?
    scope = scope.where(auditable_type: params[:record_type]) if params[:record_type].present?
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
    scope = scope.with_verb(params[:verb]) if params[:verb].present? && AuditEvent::VERBS.include?(params[:verb])
    if params[:q].present?
      scope = scope.left_joins(:user).where(
        "audit_events.action ILIKE :q OR audit_events.details ILIKE :q OR audit_events.auditable_type ILIKE :q OR users.name ILIKE :q OR users.email ILIKE :q",
        q: like_query
      )
    end
    if params[:from].present?
      starts = Time.zone.parse(params[:from]) rescue nil
      scope = scope.where("audit_events.created_at >= ?", starts.beginning_of_day) if starts
    end
    if params[:to].present?
      ends = Time.zone.parse(params[:to]) rescue nil
      scope = scope.where("audit_events.created_at <= ?", ends.end_of_day) if ends
    end
    scope
  end
end
