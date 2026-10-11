class RefundInvoice
  Result = Struct.new(:success?, :error, keyword_init: true)

  def initialize(invoice:, reason: nil, amount: nil)
    @invoice = invoice
    @reason = reason.to_s.presence
    @amount = amount
  end

  def call
    return failure(I18n.t("clinic_errors.refund_paid_only")) unless @invoice.status == "paid"
    return failure(I18n.t("clinic_errors.refund_already")) if @invoice.status == "refunded"

    refundable = @invoice.amount.to_d - @invoice.refunded_amount.to_d
    return failure(I18n.t("clinic_errors.refund_nothing")) if refundable <= 0

    refund = @amount.present? ? @amount.to_d : refundable
    refund = refundable if refund > refundable
    return failure(I18n.t("clinic_errors.refund_positive")) if refund <= 0

    released = []
    ActiveRecord::Base.transaction do
      @invoice.bookings.live.find_each do |booking|
        booking.update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: @reason || "Refund")
        released << booking
      end

      new_total = @invoice.refunded_amount.to_d + refund
      @invoice.update!(
        refunded_amount: new_total,
        refunded_at: Time.current,
        refund_reason: @reason,
        status: new_total.positive? ? "refunded" : "paid"
      )
    end
    released.each { |booking| WaitlistOffer.call(room: booking.room, starts_at: booking.start_time, ends_at: booking.end_time) }

    Result.new(success?: true)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  end

  private

  def failure(message)
    Result.new(success?: false, error: message)
  end
end
