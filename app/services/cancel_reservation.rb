class CancelReservation
  Result = Struct.new(:success?, :error, :fee, :refund, :offered, keyword_init: true)

  def initialize(booking:, reason: nil)
    @booking = booking
    @reason = reason.to_s.presence
  end

  def call
    return failure("This booking is already cancelled") if @booking.status == "cancelled"
    return failure("Completed bookings cannot be cancelled") if @booking.status == "completed"

    if ClinicPolicy.monthly?(@booking)
      cancel_monthly
    else
      cancel_single
    end
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  end

  private

  def cancel_single
    fee = ClinicPolicy.fee_for(@booking)
    refund = ClinicPolicy.refund_for(@booking)
    offered = nil

    ActiveRecord::Base.transaction do
      @booking.update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: @reason)
      settle_invoice!(@booking.invoice, fee: fee, refund: refund) if @booking.invoice
    end

    offered = WaitlistOffer.call(room: @booking.room, starts_at: @booking.start_time, ends_at: @booking.end_time)
    Result.new(success?: true, fee: fee, refund: refund, offered: offered)
  end

  def cancel_monthly
    series = ClinicPolicy.monthly_series(@booking)
    settlement = ClinicPolicy.monthly_settlement(@booking)
    invoices = Invoice.where(id: series.map(&:invoice_id).compact.uniq)
    released = []

    ActiveRecord::Base.transaction do
      series.each do |item|
        next if item.status == "cancelled"

        item.update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: @reason)
        released << item
      end

      invoices.find_each do |invoice|
        if invoice.status == "paid" || invoice.paid_at.present?
          if invoice.id == @booking.invoice_id
            settle_invoice!(invoice, fee: settlement[:fee], refund: settlement[:refund], force_series: true)
          else
            leftover = invoice.amount.to_d - invoice.refunded_amount.to_d
            settle_invoice!(invoice, fee: 0, refund: leftover, force_series: true)
          end
        else
          invoice.update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: @reason) if invoice.cancellable?
        end
      end
    end

    offered = nil
    released.select { |item| item.start_time.present? && item.start_time >= Time.current }.each do |item|
      offered = WaitlistOffer.call(room: item.room, starts_at: item.start_time, ends_at: item.end_time) || offered
    end

    Result.new(success?: true, fee: settlement[:fee], refund: settlement[:refund], offered: offered)
  end

  def settle_invoice!(invoice, fee:, refund:, force_series: false)
    return if invoice.blank?

    remaining = invoice.bookings.live
    remaining = invoice.bookings.none if force_series

    if invoice.status == "paid" || (invoice.paid_at.present? && invoice.status != "cancelled")
      apply_paid_refund!(invoice, fee: fee, refund: refund, remaining: remaining)
    elsif remaining.none?
      if fee.positive? && invoice.payable?
        invoice.update!(
          amount: fee,
          cancellation_fee: fee,
          cancellation_reason: @reason,
          notes: [invoice.notes, "Cancellation fee #{Time.current.strftime('%d/%m %H:%M')}"].compact.join(" · ")
        )
      else
        invoice.update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: @reason)
      end
    else
      invoice.update!(
        amount: remaining.sum(:amount) + fee,
        cancellation_fee: invoice.cancellation_fee.to_d + fee
      )
    end
  end

  def apply_paid_refund!(invoice, fee:, refund:, remaining:)
    refundable = invoice.amount.to_d - invoice.refunded_amount.to_d
    applied_refund = [[refund.to_d, refundable].min, 0].max
    new_refunded = invoice.refunded_amount.to_d + applied_refund
    attrs = {
      refunded_amount: new_refunded,
      refunded_at: Time.current,
      refund_reason: @reason,
      cancellation_fee: invoice.cancellation_fee.to_d + fee.to_d
    }
    attrs[:status] = "refunded" if remaining.none?
    invoice.update!(attrs)
  end

  def failure(message)
    Result.new(success?: false, error: message)
  end
end
