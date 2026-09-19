class WaitlistEntry < ApplicationRecord
  include Auditable

  belongs_to :room
  belongs_to :professional

  STATUSES = %w[waiting offered booked cancelled].freeze

  validates :starts_at, :ends_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :end_after_start

  scope :waiting, -> { where(status: "waiting") }
  scope :open, -> { where(status: %w[waiting offered]) }
  scope :for_slot, lambda { |room:, starts_at:, ends_at:|
    where(room_id: room.id).where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
  }

  def waiting?
    status == "waiting"
  end

  def offered?
    status == "offered"
  end

  def slot_starts
    starts = []
    cursor = starts_at
    while cursor < ends_at
      starts << cursor.iso8601
      cursor += Room.slot_minutes.minutes
    end
    starts
  end

  private

  def end_after_start
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after start time") if ends_at <= starts_at
  end
end
