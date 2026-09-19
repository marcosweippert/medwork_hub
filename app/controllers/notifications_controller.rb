class NotificationsController < ApplicationController
  before_action :set_notification, only: :show

  def index
    @notifications = current_user.notifications.includes(:actor, :notifiable).newest
    @notifications = paginate(@notifications, per: 30)
  end

  def show
    @notification.mark_read!
    ticket = @notification.ticket
    if ticket
      redirect_to ticket_path(ticket)
    else
      redirect_to notifications_path
    end
  end

  def mark_all
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_back fallback_location: notifications_path, notice: t("notifications.marked_all")
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
