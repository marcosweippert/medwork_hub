class CancelInvoice
  Result = Struct.new(:success?, :error, :fee, :refund, keyword_init: true)

  def initialize(invoice:, reason: nil)
    @invoice = invoice
    @reason = reason.to_s.presence
  end

  def call
    return failure("This invoice is already cancelled") if @invoice.status == "cancelled"
    return failure("This invoice is already refunded") if @invoice.status == "refunded"

    if @invoice.payable?
      @invoice.cancel!(reason: @reason)
      return Result.new(success?: true, fee: 0, refund: 0)
    end

    return failure("Only paid invoices can be refunded") unless @invoice.status == "paid" || @invoice.paid_at.present?

    live = @invoice.bookings.live.to_a
    monthly = live.find { |booking| ClinicPolicy.monthly?(booking) }

    if monthly
      result = CancelReservation.new(booking: monthly, reason: @reason).call
      return result unless result.success?

      return Result.new(success?: true, fee: result.fee, refund: result.refund)
    end

    cancel_paid_bookings(live)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  end

  private

  def cancel_paid_bookings(live)
    fee = live.sum { |booking| ClinicPolicy.fee_for(booking) }
    refund = live.sum { |booking| ClinicPolicy.refund_for(booking) }
    refund = @invoice.amount.to_d - @invoice.refunded_amount.to_d if live.empty? && refund.zero?
    released = []

    ActiveRecord::Base.transaction do
      live.each do |booking|
        booking.update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: @reason)
        released << booking
      end
      apply_paid_refund!(fee, refund)
    end

    released.each do |booking|
      WaitlistOffer.call(room: booking.room, starts_at: booking.start_time, ends_at: booking.end_time)
    end

    Result.new(success?: true, fee: fee, refund: refund)
  end

  def apply_paid_refund!(fee, refund)
    refundable = @invoice.amount.to_d - @invoice.refunded_amount.to_d
    applied = [[refund.to_d, refundable].min, 0].max
    @invoice.update!(
      refunded_amount: @invoice.refunded_amount.to_d + applied,
      refunded_at: Time.current,
      refund_reason: @reason,
      cancellation_fee: @invoice.cancellation_fee.to_d + fee.to_d,
      status: "refunded"
    )
  end

  def failure(message)
    Result.new(success?: false, error: message)
  end
end
