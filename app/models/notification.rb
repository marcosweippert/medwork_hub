class Notification < ApplicationRecord
  KINDS = %w[ticket_opened ticket_message].freeze

  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  validates :kind, inclusion: { in: KINDS }
  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :newest, -> { order(created_at: :desc, id: :desc) }

  def unread?
    read_at.blank?
  end

  def mark_read!
    update!(read_at: Time.current) if unread?
  end

  def ticket
    case notifiable
    when Ticket then notifiable
    when TicketComment then notifiable.ticket
    end
  end
end
