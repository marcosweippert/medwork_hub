class ReminderDispatch
  WINDOW = (23.hours)..(25.hours)

  def self.call
    new.call
  end

  def call
    send_booking_reminders
    send_overdue_notices
  end

  private

  def send_booking_reminders
    range = WINDOW.begin.from_now..WINDOW.end.from_now
    Booking.holding.includes(:room, :invoice, professional: :user)
      .where(reminder_sent_at: nil)
      .where(start_time: range)
      .find_each do |booking|
        ClinicMailer.booking_reminder(booking).deliver_now
        booking.update_columns(reminder_sent_at: Time.current)
      rescue StandardError => e
        Rails.logger.warn("Booking reminder failed ##{booking.id}: #{e.message}")
      end
  end

  def send_overdue_notices
    Invoice.includes(:room, professional: :user)
      .where(status: "overdue")
      .where("reminder_sent_at IS NULL OR reminder_sent_at < ?", 7.days.ago)
      .find_each do |invoice|
        ClinicMailer.overdue_notice(invoice).deliver_now
        invoice.update_columns(reminder_sent_at: Time.current)
      rescue StandardError => e
        Rails.logger.warn("Overdue notice failed ##{invoice.id}: #{e.message}")
      end
  end
end
