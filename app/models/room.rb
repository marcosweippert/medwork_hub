class Room < ApplicationRecord
  SLOT_MINUTES = 30

  has_many :bookings, dependent: :destroy
  has_many :invoices
  has_many :waitlist_entries, dependent: :destroy
  has_many :room_blocks, dependent: :destroy
  has_one_attached :photo

  accepts_nested_attributes_for :room_blocks, allow_destroy: true, reject_if: :blank_block?

  validates :name, presence: true
  validates :daily_rate, :monthly_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :opens_at, :closes_at, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 24 }
  validate :closes_after_opens
  validate :room_types_are_known

  before_validation :normalize_arrays

  scope :for_professional, lambda { |professional|
    types = Array(professional&.allowed_room_types)
    if types.empty?
      none
    else
      where("room_types && ARRAY[?]::varchar[]", types)
    end
  }

  def self.slot_minutes
    Setting.current.slot_minutes
  rescue StandardError
    SLOT_MINUTES
  end

  def working_hours
    [closes_at.to_i - opens_at.to_i, 1].max
  end

  def schedule_for(date)
    return if Array(closed_weekdays).map(&:to_i).include?(date.wday)

    setting = Setting.current
    if date.sunday?
      return if setting.sunday_closed

      [opens_at, closes_at]
    elsif date.saturday?
      open = [opens_at.to_i, setting.saturday_opens_at.to_i].max
      close = [closes_at.to_i, setting.saturday_closes_at.to_i].min
      return if close <= open

      [open, close]
    else
      [opens_at, closes_at]
    end
  end

  def working_hours_on(date)
    open, close = schedule_for(date)
    return 0 if open.blank?

    close - open
  end

  def hourly_price
    return hourly_rate if hourly_rate.present? && hourly_rate.positive?

    daily_rate.to_d / working_hours
  end

  def slot_price
    hourly_price.to_d * Setting.current.slot_minutes / 60
  end

  def occupancy_on(date)
    hours = working_hours_on(date)
    return 0 if hours <= 0

    open, close = schedule_for(date)
    day_start = date.in_time_zone.change(hour: open)
    day_end = date.in_time_zone.change(hour: close)
    return 100 if blocked?(day_start, day_end)

    busy_hours = bookings.visible_on_calendar.where("start_time < ? AND end_time > ?", day_end, day_start).to_a.sum do |booking|
      overlap_start = [booking.start_time, day_start].max
      overlap_end = [booking.end_time, day_end].min
      [(overlap_end - overlap_start) / 1.hour, 0].max
    end
    ((busy_hours / hours) * 100).round
  end

  def blocked?(starts_at, ends_at)
    RoomBlock.covering?(starts_at, ends_at, room_id: id)
  end

  def slot_taken?(starts_at, ends_at)
    return true if blocked?(starts_at, ends_at)

    bookings.holding.where("start_time < ? AND end_time > ?", ends_at, starts_at).exists?
  end

  def next_bookable_date(from = Date.current)
    upcoming_free_days(from: from, limit: 1).first || from.to_date
  end

  def fully_free_on?(date)
    open, close = schedule_for(date)
    return false if open.blank?

    starts_at = date.in_time_zone.change(hour: open)
    ends_at = date.in_time_zone.change(hour: close)
    return false if starts_at < Time.current

    !slot_taken?(starts_at, ends_at)
  end

  def upcoming_free_days(from: Date.current, limit: 14)
    date = from.to_date
    found = []
    60.times do
      found << date if fully_free_on?(date)
      break if found.size >= limit

      date += 1
    end
    found
  end

  def types_label
    labels = PracticeArea.room_type_labels_for(room_types)
    labels.any? ? labels.join(", ") : "Unassigned"
  end

  def compatible_with?(professional)
    professional.present? && professional.can_reserve?(self)
  end

  private

  def closes_after_opens
    return if opens_at.blank? || closes_at.blank?
    errors.add(:closes_at, "must be after opening hour") if closes_at <= opens_at
  end

  def room_types_are_known
    unknown = Array(room_types) - PracticeArea.room_type_keys
    errors.add(:room_types, "contains an unknown type") if unknown.any?
  end

  def normalize_arrays
    self.room_types = Array(room_types).map(&:presence).compact
    self.room_types = PracticeArea.infer_room_types(name) if room_types.empty?
    self.closed_weekdays = Array(closed_weekdays).map(&:presence).compact.map(&:to_i).uniq
  end

  def blank_block?(attrs)
    attrs["starts_at"].blank? && attrs["ends_at"].blank? && Array(attrs["weekdays"]).compact_blank.empty?
  end
end
