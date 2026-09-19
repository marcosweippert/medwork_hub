class ClinicMailer < ApplicationMailer
  default from: -> { email_address_with_name(MailerConfig.from_address, Setting.current.clinic_name.presence || "MedWork Hub") }

  def booking_reminder(booking)
    @booking = booking
    @professional = booking.professional
    @whatsapp_url = whatsapp_link(
      @professional.phone,
      "Reminder: #{booking.room.name} on #{booking.start_time.strftime('%d/%m at %H:%M')}."
    )
    mail(to: @professional.user.email, subject: "Reminder: #{booking.room.name} in 24 hours")
  end

  def overdue_notice(invoice)
    @invoice = invoice
    @professional = invoice.professional
    @pix_code = invoice.pix_code
    @whatsapp_url = whatsapp_link(
      @professional.phone,
      overdue_whatsapp_text(invoice)
    )
    mail(to: @professional.user.email, subject: "Overdue invoice ##{invoice.id.to_s.rjust(4, '0')}")
  end

  def waitlist_offer(entry)
    @entry = entry
    @professional = entry.professional
    @whatsapp_url = whatsapp_link(
      @professional.phone,
      "A slot opened in #{entry.room.name} on #{entry.starts_at.strftime('%d/%m at %H:%M')}. Reserve it in MedWork Hub."
    )
    mail(to: @professional.user.email, subject: "Waitlist: #{entry.room.name} is free")
  end

  def welcome(user, password)
    @user = user
    @password = password
    @clinic = Setting.current.clinic_name.presence || "MedWork Hub"
    @login_url = new_user_session_url
    vars = {
      name: user.display_name,
      email: user.email,
      password: password,
      role: user.role.to_s.titleize,
      clinic: @clinic,
      login_url: @login_url
    }
    @welcome_html = WelcomeEmailTemplate.html_for(**vars)
    mail(to: user.email, subject: WelcomeEmailTemplate.subject_for(**vars))
  end

  private

  def whatsapp_link(phone, text)
    digits = phone.to_s.gsub(/\D/, "")
    return if digits.blank?

    digits = "55#{digits}" unless digits.start_with?("55")
    "https://wa.me/#{digits}?text=#{ERB::Util.url_encode(text)}"
  end

  def overdue_whatsapp_text(invoice)
    text = "Invoice ##{invoice.id} is overdue (#{ActionController::Base.helpers.number_to_currency(invoice.amount)})."
    text += " PIX: #{invoice.pix_code}" if invoice.pix_code.present?
    text
  end
end
