class RoomCalendar
  Slot = Struct.new(:starts_at, :ends_at, :status, :label, keyword_init: true)

  def initialize(room, start_date: Date.current, days: 7)
    @room = room
    @start_date = start_date.to_date.beginning_of_week(:sunday)
    @days = days
  end

  def dates
    @days.times.map { |offset| @start_date + offset }
  end

  def slot_minutes
    (display_opens * 60...display_closes * 60).step(Room.slot_minutes).to_a
  end

  def slot_for(date, minutes_from_midnight)
    hour, min = minutes_from_midnight.divmod(60)
    starts_at = Time.zone.local(date.year, date.month, date.day, hour, min)
    ends_at = starts_at + Room.slot_minutes.minutes
    label = format("%02d:%02d", hour, min)
    status = if !within_schedule?(date, starts_at, ends_at)
               :closed
             elsif blocked?(starts_at, ends_at)
               :blocked
             elsif (hold = hold_status(starts_at, ends_at))
               hold
             elsif starts_at < Time.current
               :past
             else
               :free
             end
    Slot.new(starts_at: starts_at, ends_at: ends_at, status: status, label: label)
  end

  private

  def display_opens
    @room.opens_at.to_i
  end

  def display_closes
    @room.closes_at.to_i
  end

  def within_schedule?(date, starts_at, ends_at)
    open, close = @room.schedule_for(date)
    return false if open.blank?

    day_start = date.in_time_zone.change(hour: open)
    day_end = date.in_time_zone.change(hour: close)
    starts_at >= day_start && ends_at <= day_end
  end

  def blocked?(starts_at, ends_at)
    week_blocks.any? { |block| block.covers?(starts_at, ends_at) }
  end

  def hold_status(starts_at, ends_at)
    booking = overlapping_bookings.find { |item| item.start_time < ends_at && item.end_time > starts_at }
    booking&.calendar_status
  end

  def overlapping_bookings
    @overlapping_bookings ||= @room.bookings.visible_on_calendar.includes(:invoice)
      .where("start_time < ? AND end_time > ?", dates.last.end_of_day, dates.first.beginning_of_day)
      .to_a
  end

  def week_blocks
    @week_blocks ||= RoomBlock.for_week(@room, dates)
  end
end
