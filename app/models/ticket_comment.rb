class TicketComment < ApplicationRecord
  belongs_to :ticket, touch: true
  belongs_to :user
  has_many :notifications, as: :notifiable, dependent: :destroy

  validates :body, presence: true
  validate :ticket_allows_comments

  after_create :touch_first_response
  after_create :notify_recipients

  private

  def touch_first_response
    return if internal?
    return if user_id == ticket.user_id

    ticket.register_first_response!
  end

  def notify_recipients
    NotifyTicket.commented(self)
  rescue StandardError => e
    Rails.logger.warn("Ticket comment notify failed: #{e.class}: #{e.message}")
  end

  def ticket_allows_comments
    return if ticket.blank? || ticket.accepts_replies?

    errors.add(:base, I18n.t("tickets.locked"))
  end
end
