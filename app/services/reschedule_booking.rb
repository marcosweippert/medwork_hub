class RescheduleBooking
  Result = Struct.new(:success?, :error, keyword_init: true)

  def initialize(booking:, start_time:, end_time: nil)
    @booking = booking
    @start_time = start_time
    @end_time = end_time
  end

  def call
    return failure(I18n.t("clinic_errors.reschedule_cancelled")) if @booking.status == "cancelled"
    starts_at = parse_time(@start_time)
    return failure(I18n.t("clinic_errors.reschedule_start")) if starts_at.blank?

    duration = @booking.end_time - @booking.start_time
    ends_at = @end_time.present? ? parse_time(@end_time) : starts_at + duration
    return failure(I18n.t("clinic_errors.end_after_start")) if ends_at <= starts_at
    return failure(I18n.t("clinic_errors.outside_hours")) unless within_schedule?(starts_at, ends_at)

    overlap = @booking.room.bookings.holding.where.not(id: @booking.id)
      .where("start_time < ? AND end_time > ?", ends_at, starts_at)
    return failure(I18n.t("clinic_errors.time_taken")) if overlap.exists?

    original_start = @booking.start_time
    original_end = @booking.end_time
    @booking.update!(
      start_time: starts_at,
      end_time: ends_at,
      rescheduled_from: original_start
    )
    WaitlistOffer.call(room: @booking.room, starts_at: original_start, ends_at: original_end)
    Result.new(success?: true)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  end

  private

  def parse_time(value)
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def within_schedule?(starts_at, ends_at)
    open, close = @booking.room.schedule_for(starts_at.to_date)
    return false if open.blank?

    day_start = starts_at.to_date.in_time_zone.change(hour: open)
    day_end = starts_at.to_date.in_time_zone.change(hour: close)
    starts_at >= day_start && ends_at <= day_end
  end

  def failure(message)
    Result.new(success?: false, error: message)
  end
end
