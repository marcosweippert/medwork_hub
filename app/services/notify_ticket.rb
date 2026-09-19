class NotifyTicket
  def self.opened(ticket)
    new(ticket: ticket).opened
  end

  def self.commented(comment)
    new(ticket: comment.ticket, comment: comment).commented
  end

  def initialize(ticket:, comment: nil)
    @ticket = ticket
    @comment = comment
  end

  def opened
    return unless Setting.current.ticket_notify_staff?

    notify(
      staff_recipients.where.not(id: @ticket.user_id),
      kind: "ticket_opened",
      actor: @ticket.user,
      notifiable: @ticket,
      title: I18n.t("notifications.ticket_opened_title"),
      body: @ticket.subject
    )
  end

  def commented
    return if @comment.blank?

    if notify_requester?
      notify(
        User.where(id: @ticket.user_id),
        kind: "ticket_message",
        actor: @comment.user,
        notifiable: @comment,
        title: I18n.t("notifications.ticket_message_title"),
        body: @ticket.subject
      )
    else
      return unless Setting.current.ticket_notify_staff?

      notify(
        staff_recipients.where.not(id: @comment.user_id),
        kind: "ticket_message",
        actor: @comment.user,
        notifiable: @comment,
        title: I18n.t("notifications.ticket_message_staff_title"),
        body: @ticket.subject
      )
    end
  end

  private

  def notify_requester?
    return false if @comment.internal?
    return false if @comment.user_id == @ticket.user_id

    Setting.current.ticket_notify_requester?
  end

  def staff_recipients
    ids = User.where(role: %w[admin staff]).pluck(:id)
    ids << @ticket.assignee_id if @ticket.assignee_id.present?
    User.where(id: ids.uniq)
  end

  def notify(recipients, kind:, actor:, notifiable:, title:, body:)
    recipients.find_each do |recipient|
      next if recipient.id == actor&.id

      Notification.create!(
        user: recipient,
        actor: actor,
        notifiable: notifiable,
        kind: kind,
        title: title,
        body: body
      )
    end
  end
end
