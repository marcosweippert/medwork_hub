class CreateReservation
  Result = Struct.new(:success?, :invoice, :error, keyword_init: true)

  def initialize(room:, professional:, billing_type:, slots: [], month: nil, day: nil, weeks: 1)
    @room = room
    @professional = professional
    @billing_type = billing_type.to_s
    @slots = Array(slots)
    @month = month
    @day = day
    @weeks = weeks.to_i
    @weeks = 1 if @weeks < 1
    @weeks = 26 if @weeks > 26
  end

  def call
    return failure("Select a professional") if @professional.blank?
    if @professional.delinquent?
      return failure("This professional has overdue invoices and cannot make new reservations")
    end
    unless @professional.can_reserve?(@room)
      return failure("This professional cannot reserve this room type")
    end

    case @billing_type
    when "daily" then create_daily
    when "monthly" then create_monthly
    else create_hourly_or_daily
    end
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  end

  private

  def create_hourly_or_daily
    return failure("Select at least one available slot") if @slots.empty?

    ranges = merge_slots(@slots.map { |value| Time.zone.parse(value.to_s) }.sort)
    return failure("Could not parse selected slots") if ranges.empty?

    ranges.each do |starts_at, ends_at|
      return failure("One or more slots are outside opening hours") unless within_schedule?(starts_at, ends_at)
      return failure("This room is blocked for one or more selected times") if @room.blocked?(starts_at, ends_at)
      return failure("One or more slots are no longer available") if @room.slot_taken?(starts_at, ends_at)
    end

    expanded, skipped = expand_weekly(ranges)
    return failure("None of the repeated weeks are available") if expanded.empty?

    billing = daily_selection?(ranges) && @weeks == 1 ? "daily" : "hourly"
    amount = if billing == "daily"
               @room.daily_rate.to_d
             else
               total_hours(expanded) * @room.hourly_price
             end
    notes = "#{expanded.size} booking block(s) for #{@room.name}"
    notes += " · #{@weeks} weeks" if @weeks > 1
    notes += " · #{skipped} week(s) skipped" if skipped.positive?

    persist(
      ranges: expanded,
      amount: amount,
      billing_type: billing,
      notes: notes,
      recurrence_group_id: (@weeks > 1 || expanded.size > 1) ? SecureRandom.uuid : nil
    )
  end

  def create_daily
    date = parsed_day
    return failure("Select a valid day") if date.blank?

    open, close = @room.schedule_for(date)
    return failure("This day has no opening hours") if open.blank?

    starts_at = date.in_time_zone.change(hour: open)
    ends_at = date.in_time_zone.change(hour: close)
    return failure("Cannot reserve a day that has already started") if starts_at < Time.current
    return failure("This room is blocked on the selected day") if @room.blocked?(starts_at, ends_at)
    return failure("This day is not fully available") if @room.slot_taken?(starts_at, ends_at)

    persist(
      ranges: [[starts_at, ends_at]],
      amount: @room.daily_rate.to_d,
      billing_type: "daily",
      notes: "Daily reservation for #{@room.name} (#{date.strftime('%d/%m/%Y')})"
    )
  end

  def parsed_day
    @day.present? ? Date.parse(@day.to_s) : Date.current
  rescue Date::Error, ArgumentError
    nil
  end

  def create_monthly
    month_date = @month.present? ? Date.parse("#{@month}-01") : Date.current.beginning_of_month
    quote = MonthlyReservationQuote.new(room: @room, month: month_date.strftime("%Y-%m"), as_of: Time.current)
    return failure("No remaining days left in this month") if quote.remaining_days <= 0
    return failure("No free hours left in this month") if quote.plans.empty?

    persist(
      ranges: quote.plans.map { |plan| [plan.starts_at, plan.ends_at] },
      amount: quote.total,
      billing_type: "monthly",
      notes: quote.comment,
      recurrence_group_id: SecureRandom.uuid,
      line_amounts: quote.plans.map(&:amount)
    )
  rescue Date::Error, ArgumentError
    failure("Select a valid month")
  end

  def persist(ranges:, amount:, billing_type:, notes:, recurrence_group_id: nil, line_amount: nil, line_amounts: nil)
    invoice = nil
    ActiveRecord::Base.transaction do
      invoice = Invoice.create!(
        professional: @professional,
        room: @room,
        amount: amount,
        status: "open",
        due_date: Date.current,
        notes: notes
      )

      per = ranges.size.positive? ? (amount / ranges.size).round(2) : 0
      ranges.each_with_index do |(starts_at, ends_at), index|
        hours = ((ends_at - starts_at) / 1.hour)
        block_amount = if line_amounts
                         line_amounts[index].to_d
                       elsif !line_amount.nil?
                         line_amount
                       elsif billing_type == "hourly"
                         hours * @room.hourly_price
                       elsif index == ranges.size - 1
                         amount - (per * (ranges.size - 1))
                       else
                         per
                       end
        Booking.create!(
          professional: @professional,
          room: @room,
          invoice: invoice,
          start_time: starts_at,
          end_time: ends_at,
          status: "pending",
          billing_type: billing_type,
          amount: block_amount,
          recurrence_group_id: recurrence_group_id
        )
      end
    end

    Result.new(success?: true, invoice: invoice)
  end

  def expand_weekly(ranges)
    return [ranges, 0] if @weeks <= 1

    expanded = []
    skipped = 0
    ranges.each do |starts_at, ends_at|
      duration = ends_at - starts_at
      @weeks.times do |week|
        next_start = starts_at + week.weeks
        next_end = next_start + duration
        if week.zero?
          expanded << [next_start, next_end]
          next
        end
        unless within_schedule?(next_start, next_end) && !@room.slot_taken?(next_start, next_end)
          skipped += 1
          next
        end
        expanded << [next_start, next_end]
      end
    end
    [expanded, skipped]
  end

  def merge_slots(starts)
    duration = Room.slot_minutes.minutes
    starts.each_with_object([]) do |start_time, ranges|
      last = ranges.last
      if last && last[1] == start_time
        last[1] = start_time + duration
      else
        ranges << [start_time, start_time + duration]
      end
    end
  end

  def daily_selection?(ranges)
    return false unless ranges.one?

    starts_at, ends_at = ranges.first
    date = starts_at.to_date
    return false unless date == (ends_at - 1.second).to_date

    open, close = @room.schedule_for(date)
    return false if open.blank?

    starts_at == date.in_time_zone.change(hour: open) &&
      ends_at == date.in_time_zone.change(hour: close)
  end

  def total_hours(ranges)
    ranges.sum { |starts_at, ends_at| (ends_at - starts_at) / 1.hour }
  end

  def within_schedule?(starts_at, ends_at)
    open, close = @room.schedule_for(starts_at.to_date)
    return false if open.blank?

    day_start = starts_at.to_date.in_time_zone.change(hour: open)
    day_end = starts_at.to_date.in_time_zone.change(hour: close)
    starts_at >= day_start && ends_at <= day_end
  end

  def failure(message)
    Result.new(success?: false, error: message)
  end
end
