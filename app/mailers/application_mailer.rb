class ApplicationMailer < ActionMailer::Base
  default from: -> { MailerConfig.from_address }
  layout "mailer"
  before_action :assign_mailer_brand
  after_deliver :record_outbound_email

  private

  def assign_mailer_brand
    @clinic ||= Setting.current.clinic_name.presence || "MedWork Hub"
  rescue StandardError
    @clinic ||= "MedWork Hub"
  end

  def record_outbound_email
    return unless OutboundEmail.table_exists?

    OutboundEmail.record_from!(
      message,
      mailer: self.class.name,
      action_name: action_name,
      status: "sent"
    )
  rescue StandardError => e
    Rails.logger.error("Outbound email log failed: #{e.class}: #{e.message}")
  end
end
