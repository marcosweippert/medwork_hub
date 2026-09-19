class ClinicPolicy
  def self.fee_percent(starts_at)
    setting = Setting.current
    return setting.started_cancel_percent if starts_at.blank? || starts_at <= Time.current
    return 0 if starts_at >= Time.current + setting.free_cancel_hours.hours

    setting.late_cancel_percent
  end

  def self.fee_for(booking)
    (chargeable_amount(booking) * fee_percent(booking.start_time) / 100).round(2)
  end

  def self.refund_for(booking)
    chargeable_amount(booking) - fee_for(booking)
  end

  def self.chargeable_amount(booking)
    amount = booking.amount.to_d
    return amount if amount.positive?

    invoice = booking.invoice
    return 0 if invoice.blank?

    siblings = invoice.bookings.live
    divisor = [siblings.count, 1].max
    (invoice.amount.to_d / divisor)
  end

  def self.monthly?(booking)
    booking.billing_type.to_s == "monthly"
  end

  def self.monthly_settlement(booking, as_of: Time.current)
    series = monthly_series(booking)
    invoice = booking.invoice
    amount = invoice&.amount.to_d
    amount = series.sum { |item| item.amount.to_d } if amount <= 0
    day_share = booking.room.monthly_rate.to_d / 30
    used_days = series.count { |item| item.start_time.present? && item.start_time < as_of }
    slot_fee = booking.room.slot_price.to_d
    fee = [(used_days * day_share) + slot_fee, amount].min.round(2)
    refund = [amount - fee, 0].max.round(2)
    {
      fee: fee,
      refund: refund,
      used_days: used_days,
      total_days: series.size,
      day_share: day_share.round(2),
      slot_fee: slot_fee
    }
  end

  def self.monthly_series(booking)
    series = booking.series_bookings.to_a
    return series if series.size > 1
    return booking.invoice.bookings.to_a if booking.invoice.present? && booking.invoice.bookings.size > 1

    Array(booking)
  end

  def self.summary
    setting = Setting.current
    {
      free_hours: setting.free_cancel_hours,
      late_percent: setting.late_cancel_percent,
      started_percent: setting.started_cancel_percent
    }
  end
end
