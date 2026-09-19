module TicketsHelper
  def sla_class(ticket)
    "sla-#{ticket.sla_state}"
  end

  def ticket_status_options
    Ticket::STATUSES.map { |status| [t("statuses.#{status}", default: status.humanize), status] }
  end

  def ticket_priority_options
    Ticket::PRIORITIES.map { |priority| [t("statuses.#{priority}", default: priority.humanize), priority] }
  end

  def ticket_category_options
    Ticket::CATEGORIES.map { |category| [t("statuses.#{category}", default: category.humanize), category] }
  end

  def staff_assignees
    User.where(role: %w[admin staff]).order(:name)
  end

  def ticket_filters_active?
    params.values_at(:q, :status, :priority, :category, :assignee_id, :mine, :unassigned, :sla, :queue, :tab).any?(&:present?)
  end

  def ticket_filter_params
    request.query_parameters.slice("q", "priority", "category", "assignee_id", "mine", "tab")
  end
end
