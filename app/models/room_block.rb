class RoomBlock < ApplicationRecord
  include Auditable

  belongs_to :room, optional: true

  validates :starts_at, :ends_at, presence: true
  validate :end_after_start
  before_validation :normalize_weekdays

  scope :overlapping, lambda { |starts_at, ends_at|
    where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
  }
  scope :recurring, -> { where("COALESCE(array_length(weekdays, 1), 0) > 0") }
  scope :one_off, -> { where("COALESCE(array_length(weekdays, 1), 0) = 0") }

  def self.covering?(starts_at, ends_at, room_id:)
    scoped = where("room_id IS NULL OR room_id = ?", room_id)
    return true if scoped.one_off.overlapping(starts_at, ends_at).exists?

    scoped.recurring.find_each.any? { |block| block.covers?(starts_at, ends_at) }
  end

  def self.for_week(room, dates)
    scoped = where("room_id IS NULL OR room_id = ?", room.id)
    (
      scoped.one_off.overlapping(dates.first.beginning_of_day, dates.last.end_of_day).to_a +
      scoped.recurring.to_a
    ).uniq
  end

  def covers?(starts_at, ends_at)
    if recurring?
      return false unless weekdays.map(&:to_i).include?(starts_at.wday)

      slot_start = minutes_since_midnight(starts_at)
      slot_end = minutes_since_midnight(ends_at)
      block_start = minutes_since_midnight(self.starts_at)
      block_end = minutes_since_midnight(self.ends_at)
      slot_start < block_end && slot_end > block_start
    else
      self.starts_at < ends_at && self.ends_at > starts_at
    end
  end

  def label
    base = reason.presence || "Blocked"
    recurring? ? "#{base} · weekly" : base
  end

  def clinic_wide?
    room_id.blank?
  end

  def recurring?
    Array(weekdays).any?
  end

  def weekdays_label
    names = %w[Sun Mon Tue Wed Thu Fri Sat]
    Array(weekdays).map(&:to_i).sort.map { |day| names[day] }.join(", ")
  end

  private

  def end_after_start
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after start time") if ends_at <= starts_at
  end

  def normalize_weekdays
    self.weekdays = Array(weekdays).map(&:presence).compact.map(&:to_i).uniq
  end

  def minutes_since_midnight(time)
    time.hour * 60 + time.min
  end
end
