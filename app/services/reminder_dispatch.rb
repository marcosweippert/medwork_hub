class ReminderDispatch
  WINDOW = (23.hours)..(25.hours)
  MAX_PER_RUN = 50
  MIN_INTERVAL = 10.minutes
  DEMO_EMAIL_SUFFIX = "@medworkhub.com"

  def self.call
    new.call
  end

  def call
    return unless MailerConfig.smtp_configured?
    return unless claim_run!

    send_booking_reminders
    send_overdue_notices
  end

  private

  def claim_run!
    now = Time.current
    mutex.synchronize do
      last = self.class.instance_variable_get(:@last_run_at)
      return false if last && last > MIN_INTERVAL.ago

      self.class.instance_variable_set(:@last_run_at, now)
      true
    end
  end

  def mutex
    self.class.instance_variable_get(:@mutex) || self.class.instance_variable_set(:@mutex, Mutex.new)
  end

  def send_booking_reminders
    range = WINDOW.begin.from_now..WINDOW.end.from_now
    Booking.holding.includes(:room, :invoice, professional: :user)
      .where(reminder_sent_at: nil)
      .where(start_time: range)
      .limit(MAX_PER_RUN)
      .each { |booking| deliver_reminder(booking) }
  end

  def send_overdue_notices
    Invoice.includes(:room, professional: :user)
      .where(status: "overdue")
      .where("reminder_sent_at IS NULL OR reminder_sent_at < ?", 7.days.ago)
      .limit(MAX_PER_RUN)
      .each { |invoice| deliver_overdue(invoice) }
  end

  def deliver_reminder(booking)
    email = booking.professional&.user&.email
    if demo_email?(email)
      booking.update_columns(reminder_sent_at: Time.current)
      return
    end

    ClinicMailer.booking_reminder(booking).deliver_now
    booking.update_columns(reminder_sent_at: Time.current)
  rescue StandardError => e
    Rails.logger.warn("Booking reminder failed ##{booking.id}: #{e.message}")
  end

  def deliver_overdue(invoice)
    email = invoice.professional&.user&.email
    if demo_email?(email)
      invoice.update_columns(reminder_sent_at: Time.current)
      return
    end

    ClinicMailer.overdue_notice(invoice).deliver_now
    invoice.update_columns(reminder_sent_at: Time.current)
  rescue StandardError => e
    Rails.logger.warn("Overdue notice failed ##{invoice.id}: #{e.message}")
  end

  def demo_email?(email)
    email.to_s.downcase.end_with?(DEMO_EMAIL_SUFFIX)
  end
end
