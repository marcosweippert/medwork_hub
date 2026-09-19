class OutboundMailer < ApplicationMailer
  def replay(outbound_email, to: nil)
    @outbound_email = outbound_email
    recipients = to.presence || outbound_email.to_address
    mail(
      to: recipients,
      cc: (outbound_email.cc if to.blank?),
      bcc: (outbound_email.bcc if to.blank?),
      from: outbound_email.from_address.presence || MailerConfig.from_address,
      subject: forwarded?(to) ? forwarded_subject(outbound_email.subject) : outbound_email.subject.to_s
    ) do |format|
      if outbound_email.html?
        format.html { render html: outbound_email.body_html.html_safe }
      end
      format.text { render plain: outbound_email.body_text.presence || outbound_email.subject }
    end
  end

  def compose(to:, subject:, body:)
    @body = body.to_s
    @clinic = Setting.current.clinic_name.presence || "MedWork Hub"
    mail(to: to, subject: subject.presence || "Message from #{@clinic}")
  end

  private

  def forwarded?(to)
    to.present?
  end

  def forwarded_subject(subject)
    text = subject.to_s
    text.start_with?("Fwd:") ? text : "Fwd: #{text}"
  end
end
