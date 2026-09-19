require "csv"

class TicketsController < ApplicationController
  before_action :set_ticket, only: %i[show update comment take reopen resolve]

  def index
    @tickets = ticket_scope.includes(:user, :assignee).order(updated_at: :desc)
    @tickets = apply_ticket_filters(@tickets)
    @stats = ticket_stats
    @tickets = paginate(@tickets, per: 20)
  end

  def show
    @comments = visible_comments
    @comment = TicketComment.new
  end

  def new
    @ticket = Ticket.new(priority: Setting.current.ticket_default_priority.presence || "medium", category: "other")
  end

  def create
    @ticket = current_user.tickets.new(ticket_params)
    if @ticket.save
      redirect_to @ticket, notice: t("tickets.opened")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    unless clinic_staff?
      redirect_to @ticket, alert: t("tickets.staff_only")
      return
    end

    Ticket.transaction do
      @ticket.update!(staff_params.except(:status))
      @ticket.apply_status!(staff_params[:status]) if staff_params[:status].present?
    end
    redirect_to @ticket, notice: t("tickets.updated")
  rescue ActiveRecord::RecordInvalid
    @comments = visible_comments
    @comment = TicketComment.new
    render :show, status: :unprocessable_entity
  end

  def take
    unless clinic_staff?
      redirect_to @ticket, alert: t("tickets.staff_only")
      return
    end

    attrs = { assignee: current_user }
    attrs[:status] = "in_progress" if @ticket.status == "open"
    @ticket.update!(attrs)
    redirect_to @ticket, notice: t("tickets.taken")
  end

  def reopen
    unless clinic_staff?
      redirect_to @ticket, alert: t("tickets.staff_only")
      return
    end

    @ticket.update!(status: "open", closed_at: nil)
    redirect_to @ticket, notice: t("tickets.reopened")
  end

  def resolve
    unless clinic_staff?
      redirect_to @ticket, alert: t("tickets.staff_only")
      return
    end

    @ticket.apply_status!("resolved")
    redirect_to tickets_path, notice: t("tickets.updated")
  end

  def comment
    unless @ticket.accepts_replies?
      redirect_to @ticket, alert: t("tickets.locked")
      return
    end

    @comment = @ticket.ticket_comments.new(comment_params.merge(user: current_user))
    @comment.internal = false unless clinic_staff?
    if @comment.save
      redirect_to @ticket, notice: t("tickets.replied")
    else
      @comments = visible_comments
      render :show, status: :unprocessable_entity
    end
  end

  def bulk
    unless clinic_staff?
      redirect_to tickets_path, alert: t("tickets.staff_only")
      return
    end

    tickets = ticket_scope.where(id: Array(params[:ids]))
    case params[:bulk_action]
    when "resolve"
      tickets.find_each { |ticket| ticket.apply_status!("resolved") }
      notice = t("tickets.bulk_resolved")
    when "close"
      tickets.find_each { |ticket| ticket.apply_status!("closed") }
      notice = t("tickets.bulk_closed")
    else
      notice = t("tickets.updated")
    end
    redirect_to tickets_path, notice: notice
  end

  def export
    unless clinic_staff?
      redirect_to tickets_path, alert: t("tickets.staff_only")
      return
    end

    tickets = apply_ticket_filters(ticket_scope.includes(:user, :assignee).order(updated_at: :desc))
    csv = CSV.generate(headers: true) do |rows|
      rows << %w[id subject requester status priority agent created_at]
      tickets.find_each do |ticket|
        rows << [ticket.id, ticket.subject, ticket.user.display_name, ticket.status, ticket.priority, ticket.assignee&.display_name, ticket.created_at.iso8601]
      end
    end
    send_data csv, filename: "tickets-#{Date.current}.csv", type: "text/csv"
  end

  private

  def ticket_scope
    clinic_staff? ? Ticket.all : current_user.tickets
  end

  def ticket_stats
    scope = ticket_scope
    {
      total: scope.count,
      pending: scope.open_queue.count,
      solved: scope.where(status: "resolved").count,
      closed: scope.where(status: "closed").count
    }
  end

  def apply_ticket_filters(scope)
    case params[:tab]
    when "pending" then scope = scope.open_queue
    when "solved" then scope = scope.where(status: "resolved")
    when "closed" then scope = scope.where(status: "closed")
    end
    scope = scope.open_queue if params[:queue] == "open"
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(priority: params[:priority]) if params[:priority].present?
    scope = scope.where(category: params[:category]) if params[:category].present?
    scope = scope.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    scope = scope.where(assignee_id: current_user.id) if params[:mine] == "1"
    scope = scope.unassigned if params[:unassigned] == "1"
    scope = scope.breached if params[:sla] == "breached"
    if params[:q].present?
      scope = scope.left_joins(:user).where(
        "tickets.subject ILIKE :q OR tickets.body ILIKE :q OR users.name ILIKE :q OR users.email ILIKE :q",
        q: like_query
      )
    end
    scope
  end

  def set_ticket
    @ticket = ticket_scope.find(params[:id])
  end

  def visible_comments
    comments = @ticket.ticket_comments.includes(:user).order(:created_at)
    clinic_staff? ? comments : comments.where(internal: false)
  end

  def ticket_params
    params.require(:ticket).permit(:subject, :body, :priority, :category)
  end

  def staff_params
    params.require(:ticket).permit(:status, :priority, :assignee_id, :category)
  end

  def comment_params
    params.require(:ticket_comment).permit(:body, :internal)
  end
end
