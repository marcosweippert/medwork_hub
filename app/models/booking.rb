class Booking < ApplicationRecord
  include Auditable

  belongs_to :professional
  belongs_to :room
  belongs_to :invoice, optional: true
  belongs_to :patient, optional: true
  has_many :appointment_notes, dependent: :destroy

  STATUSES = %w[pending scheduled confirmed cancelled completed].freeze
  BILLING_TYPES = %w[hourly daily monthly].freeze

  validates :start_time, :end_time, presence: true
  validates :status, inclusion: { in: STATUSES }, allow_blank: true
  validate :end_after_start
  validate :no_overlap
  validate :not_blocked
  validate :room_matches_professional

  scope :live, -> { where.not(status: %w[cancelled completed]) }
  scope :holding, lambda {
    live.left_joins(:invoice).where(
      "(invoices.id IS NULL AND bookings.status IN (:live_status)) OR invoices.status IN (:holding_status)",
      live_status: %w[pending scheduled confirmed],
      holding_status: %w[open paid]
    )
  }
  scope :reserved, -> { live.joins(:invoice).where(invoices: { status: "open" }) }
  scope :occupied, -> { live.joins(:invoice).where(invoices: { status: "paid" }) }
  scope :blocking, -> { holding }
  scope :upcoming, -> { holding.where("start_time >= ?", Time.current).order(:start_time) }
  scope :series, ->(group_id) { where(recurrence_group_id: group_id) if group_id.present? }

  def duration_hours
    return 0 unless start_time && end_time

    ((end_time - start_time) / 1.hour).round(2)
  end

  def slot_starts
    return [] unless start_time && end_time

    starts = []
    cursor = start_time
    step = Room.slot_minutes.minutes
    while cursor < end_time
      starts << cursor
      cursor += step
    end
    starts
  end

  def self.merge_slot_starts(starts)
    duration = Room.slot_minutes.minutes
    Array(starts).sort.each_with_object([]) do |start_time, ranges|
      last = ranges.last
      if last && last[1] == start_time
        last[1] = start_time + duration
      else
        ranges << [start_time, start_time + duration]
      end
    end
  end

  def calendar_status
    return if status == "cancelled"
    return :occupied if invoice&.status == "paid" || (invoice.nil? && status == "confirmed")
    return :reserved if invoice.nil? || invoice.status == "open"

    nil
  end

  def cancellable?
    status.in?(%w[pending scheduled confirmed]) && start_time.present?
  end

  def reschedulable?
    cancellable? && start_time > Time.current
  end

  def recurring?
    recurrence_group_id.present?
  end

  def series_bookings
    return Booking.none unless recurring?

    Booking.where(recurrence_group_id: recurrence_group_id).order(:start_time)
  end

  def cancellation_fee
    if ClinicPolicy.monthly?(self)
      ClinicPolicy.monthly_settlement(self)[:fee]
    else
      ClinicPolicy.fee_for(self)
    end
  end

  def cancellation_refund
    if ClinicPolicy.monthly?(self)
      ClinicPolicy.monthly_settlement(self)[:refund]
    else
      ClinicPolicy.refund_for(self)
    end
  end

  def reminder_window?
    start_time.present? && start_time.between?(23.hours.from_now, 25.hours.from_now)
  end

  private

  def end_after_start
    return if start_time.blank? || end_time.blank?
    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end

  def no_overlap
    return if start_time.blank? || end_time.blank? || room_id.blank?
    return if status == "cancelled"

    overlap = room.bookings.holding.where.not(id: id).where("start_time < ? AND end_time > ?", end_time, start_time)
    errors.add(:base, "This room is already booked for the selected time") if overlap.exists?
  end

  def not_blocked
    return if start_time.blank? || end_time.blank? || room_id.blank?
    return if status == "cancelled"

    errors.add(:base, "This room is blocked for the selected time") if room.blocked?(start_time, end_time)
  end

  def room_matches_professional
    return if professional.blank? || room.blank?
    return if status == "cancelled"
    return if professional.can_reserve?(room)

    errors.add(:base, "This professional cannot reserve this room type")
  end
end
