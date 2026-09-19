require "csv"

class AuditEventsController < ApplicationController
  before_action :require_admin
  before_action :set_event, only: %i[show destroy]

  def index
    @actions = AuditEvent.distinct.order(:action).pluck(:action)
    @record_types = AuditEvent.distinct.order(:auditable_type).pluck(:auditable_type).compact
    @users = User.order(:name, :email)
    @stats = {
      total: AuditEvent.count,
      today: AuditEvent.where("created_at >= ?", Time.zone.today.beginning_of_day).count,
      updates: AuditEvent.where("action LIKE ?", "%.updated").count,
      deletes: AuditEvent.where("action LIKE ?", "%.deleted").count
    }
    @events = paginate(filtered_events, per: 30)
  end

  def show; end

  def export
    csv = CSV.generate(headers: true) do |rows|
      rows << %w[When User Action Record Details]
      filtered_events.limit(2000).each do |event|
        rows << [
          event.created_at.strftime("%d/%m/%Y %H:%M:%S"),
          event.actor_name,
          event.action,
          event.record_name,
          event.details
        ]
      end
    end
    send_data csv, filename: "audit-log-#{Time.zone.today.iso8601}.csv", type: "text/csv"
  end

  def bulk
    events = AuditEvent.where(id: Array(params[:event_ids]))
    case params[:bulk_action]
    when "delete"
      count = events.count
      events.delete_all
      redirect_to audit_events_path, notice: "Removed #{count} audit event(s)."
    else
      redirect_to audit_events_path, alert: "Choose a bulk action."
    end
  end

  def destroy
    @event.destroy
    redirect_to audit_events_path, notice: "Event removed from the log."
  end

  private

  def set_event
    @event = AuditEvent.find(params[:id])
  end

  def filtered_events
    scope = AuditEvent.includes(:user).newest
    scope = scope.where(action: params[:action_name]) if params[:action_name].present?
    scope = scope.where(auditable_type: params[:record_type]) if params[:record_type].present?
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
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
