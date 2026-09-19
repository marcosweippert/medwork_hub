class CancelBookingSlots
  Result = Struct.new(:success?, :error, :fee, :refund, keyword_init: true)

  def initialize(invoice:, slot_starts:, reason: nil)
    @invoice = invoice
    @slot_starts = Array(slot_starts).filter_map { |value| parse_time(value) }
    @reason = reason.to_s.presence || "Selected slots cancelled"
  end

  def call
    return failure("Select at least one time slot") if @slot_starts.empty?
    return failure("This invoice is already cancelled") if @invoice.status == "cancelled"
    return failure("This invoice is already refunded") if @invoice.status == "refunded"

    selected = selected_slots
    return failure("None of the selected slots are on a live hourly booking") if selected.empty?
    if selected.any? { |item| item[:start] <= Time.current }
      return failure("Started slots cannot be cancelled. Uncheck times that already began.")
    end

    paid = @invoice.status == "paid" || @invoice.paid_at.present?
    fee = 0.to_d
    refund = 0.to_d
    released = []

    ActiveRecord::Base.transaction do
      selected.group_by { |item| item[:booking] }.each do |booking, items|
        cancelled_starts = items.map { |item| item[:start] }
        share = slot_share(booking)
        cancelled_starts.each do |start_time|
          piece_fee = (share * ClinicPolicy.fee_percent(start_time) / 100).round(2)
          fee += piece_fee
          refund += share - piece_fee
        end

        remaining_starts = booking.slot_starts.reject { |start_time| cancelled_starts.map(&:to_i).include?(start_time.to_i) }
        remaining_ranges = Booking.merge_slot_starts(remaining_starts)
        cancelled_ranges = Booking.merge_slot_starts(cancelled_starts)
        released.concat(cancelled_ranges.map { |range| { room: booking.room, starts_at: range[0], ends_at: range[1] } })

        split_booking!(booking, remaining_ranges, cancelled_ranges, share)
      end

      settle_invoice!(fee, refund)
    end

    released.each do |slot|
      WaitlistOffer.call(room: slot[:room], starts_at: slot[:starts_at], ends_at: slot[:ends_at])
    end

    Result.new(success?: true, fee: fee, refund: paid ? refund : 0)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  end

  private

  def selected_slots
    wanted = @slot_starts.map(&:to_i).to_set
    @invoice.bookings.live.includes(:room).flat_map do |booking|
      next [] unless booking.billing_type.to_s == "hourly"

      booking.slot_starts.filter_map do |start_time|
        next unless wanted.include?(start_time.to_i)

        { booking: booking, start: start_time }
      end
    end
  end

  def slot_share(booking)
    count = [booking.slot_starts.size, 1].max
    (booking.amount.to_d / count).round(2)
  end

  def split_booking!(booking, remaining_ranges, cancelled_ranges, share)
    remaining_ranges.each_with_index do |(starts_at, ends_at), index|
      attrs = {
        start_time: starts_at,
        end_time: ends_at,
        amount: (slot_count(starts_at, ends_at) * share).round(2)
      }
      if index.zero?
        booking.update!(attrs)
      else
        clone_booking!(booking, attrs.merge(status: booking.status))
      end
    end

    cancelled_ranges.each_with_index do |(starts_at, ends_at), index|
      attrs = {
        start_time: starts_at,
        end_time: ends_at,
        amount: (slot_count(starts_at, ends_at) * share).round(2),
        status: "cancelled",
        cancelled_at: Time.current,
        cancellation_reason: @reason
      }
      if remaining_ranges.empty? && index.zero?
        booking.update!(attrs)
      else
        clone_booking!(booking, attrs)
      end
    end
  end

  def clone_booking!(booking, attrs)
    Booking.create!(
      professional: booking.professional,
      room: booking.room,
      invoice: booking.invoice,
      patient: booking.patient,
      billing_type: booking.billing_type,
      recurrence_group_id: booking.recurrence_group_id,
      **attrs
    )
  end

  def slot_count(starts_at, ends_at)
    ((ends_at - starts_at) / Room.slot_minutes.minutes).round
  end

  def settle_invoice!(fee, refund)
    live_amount = @invoice.bookings.live.sum(:amount)
    if @invoice.payable?
      if live_amount.zero?
        @invoice.update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: @reason, amount: 0)
      else
        @invoice.update!(amount: live_amount)
      end
      return
    end

    return unless @invoice.status == "paid" || @invoice.paid_at.present?

    refundable = @invoice.amount.to_d - @invoice.refunded_amount.to_d
    applied = [[refund.to_d, refundable].min, 0].max
    attrs = {
      refunded_amount: @invoice.refunded_amount.to_d + applied,
      refunded_at: Time.current,
      refund_reason: @reason,
      cancellation_fee: @invoice.cancellation_fee.to_d + fee.to_d
    }
    attrs[:status] = "refunded" if @invoice.bookings.live.none?
    @invoice.update!(attrs)
  end

  def parse_time(value)
    time = value.is_a?(Time) ? value : Time.zone.parse(value.to_s)
    time&.change(sec: 0)
  rescue ArgumentError
    nil
  end

  def failure(message)
    Result.new(success?: false, error: message, fee: 0, refund: 0)
  end
end
