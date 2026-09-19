class MonthlyReservationQuote
  Plan = Struct.new(:starts_at, :ends_at, :amount, :occupied_slots, keyword_init: true)

  def initialize(room:, month:, as_of: Time.current)
    @room = room
    @month_start = Date.parse("#{month}-01")
    @as_of = as_of
  end

  def from_date
    today = @as_of.in_time_zone.to_date
    today > @month_start ? today : @month_start
  end

  def to_date
    @month_start.end_of_month
  end

  def remaining_days
    return 0 if from_date > to_date

    (from_date..to_date).count
  end

  def day_rate
    (@room.monthly_rate.to_d / 30).round(2)
  end

  def hours_per_day
    @room.working_hours
  end

  def slots_per_hour
    [60 / Room.slot_minutes, 1].max
  end

  def hour_rate
    @room.monthly_rate.to_d / 30 / hours_per_day
  end

  def slot_deduction
    (@room.monthly_rate.to_d / 30 / hours_per_day / slots_per_hour).round(2)
  end

  def occupied_slots
    build_plans unless defined?(@occupied_slots)
    @occupied_slots
  end

  def plans
    build_plans
    @plans
  end

  def base_amount
    (day_rate * remaining_days).round(2)
  end

  def deduction
    (slot_deduction * occupied_slots).round(2)
  end

  def total
    [base_amount - deduction, 0].max.round(2)
  end

  def comment
    [
      "Cálculo da reserva mensal (#{@month_start.strftime('%B %Y')}):",
      "Valor mensal: #{money(@room.monthly_rate)}",
      "Valor do dia: #{money(@room.monthly_rate)} / 30 = #{money(day_rate)}",
      "Dias restantes: #{from_date.strftime('%d/%m')} a #{to_date.strftime('%d/%m')} = #{remaining_days} × #{money(day_rate)} = #{money(base_amount)}",
      "Dedução por 30 min já reservado no calendário da sala (#{format('%02d:00', @room.opens_at)}–#{format('%02d:00', @room.closes_at)}, slots de #{Room.slot_minutes} min): #{money(@room.monthly_rate)} / 30 / #{hours_per_day}h / #{slots_per_hour} = #{money(slot_deduction)}",
      "Slots de 30 min ocupados/bloqueados no calendário: #{occupied_slots} × #{money(slot_deduction)} = #{money(deduction)}",
      "Total: #{money(base_amount)} − #{money(deduction)} = #{money(total)}"
    ].join("\n")
  end

  private

  def build_plans
    return if defined?(@plans)

    @plans = []
    @occupied_slots = 0
    return if remaining_days.zero?

    slot_minutes = Room.slot_minutes
    holds = load_holds
    blocks = RoomBlock.for_week(@room, (from_date..to_date).to_a)

    (from_date..to_date).each do |date|
      open, close = @room.schedule_for(date)
      next if open.blank?

      day_start = date.in_time_zone.change(hour: open)
      day_end = date.in_time_zone.change(hour: close)
      cursor = day_start
      free_run = nil
      day_occupied = 0
      day_ranges = []

      while cursor < day_end
        slot_end = cursor + slot_minutes.minutes
        taken = unavailable?(cursor, slot_end, holds, blocks)
        past = cursor < @as_of
        if taken
          day_occupied += 1
          if free_run
            day_ranges << [free_run, cursor]
            free_run = nil
          end
        elsif past
          if free_run
            day_ranges << [free_run, cursor]
            free_run = nil
          end
        else
          free_run ||= cursor
        end
        cursor = slot_end
      end
      day_ranges << [free_run, day_end] if free_run

      @occupied_slots += day_occupied
      next if day_ranges.empty?

      occupied_value = (slot_deduction * day_occupied).round(2)
      allocated = 0
      day_ranges.each_with_index do |(starts_at, ends_at), index|
        hours = (ends_at - starts_at) / 1.hour
        amount = if index == day_ranges.size - 1
                   [day_rate - occupied_value - allocated, 0].max.round(2)
                 else
                   (hour_rate * hours).round(2)
                 end
        allocated += amount
        @plans << Plan.new(
          starts_at: starts_at,
          ends_at: ends_at,
          amount: amount,
          occupied_slots: day_occupied
        )
      end
    end
  end

  def unavailable?(starts_at, ends_at, holds, blocks)
    return true if blocks.any? { |block| block.covers?(starts_at, ends_at) }

    holds.any? { |booking| booking.start_time < ends_at && booking.end_time > starts_at }
  end

  def load_holds
    @room.bookings.holding.where("start_time < ? AND end_time > ?", to_date.end_of_day, from_date.beginning_of_day).to_a
  end

  def money(value)
    format("%.2f", value.to_d)
  end
end
