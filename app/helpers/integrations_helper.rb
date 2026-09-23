module IntegrationsHelper
  def integration_resource_links(integration)
    links = []
    case integration.kind
    when "smtp"
      links << [t("integrations.resources.mail_settings"), settings_path(edit: "mail")]
      links << [t("integrations.resources.outbound_emails"), outbound_emails_path]
      links << [t("integrations.resources.email_report"), emails_reports_path]
    when "pix"
      links << [t("integrations.resources.pix_settings"), settings_path(edit: "pix")]
      links << [t("integrations.resources.invoices"), invoices_path]
      links << [t("integrations.resources.receivables"), receivables_reports_path]
    when "whatsapp"
      links << [t("integrations.resources.whatsapp_settings"), settings_path(edit: "pix")]
      links << [t("integrations.resources.invoices"), invoices_path]
    when "calendar"
      links << [t("integrations.resources.room_calendar"), calendar_bookings_path]
      links << [t("integrations.resources.availability"), availability_rooms_path]
      links << [t("integrations.resources.waitlist"), waitlist_entries_path]
      links << [t("integrations.resources.blocks"), room_blocks_path]
    when "n8n"
      links << [t("integrations.resources.api_keys"), api_keys_path]
      links << [t("integrations.resources.workflow"), "/n8n/medwork-hub-events.json"]
      links << [t("integrations.resources.tickets"), tickets_path]
      links << [t("integrations.resources.bookings"), bookings_path]
    when "slack", "discord", "telegram", "microsoft_teams"
      links << [t("integrations.resources.tickets"), tickets_path]
      links << [t("integrations.resources.bookings"), bookings_path]
      links << [t("integrations.resources.api_keys"), api_keys_path]
    when "google_calendar", "outlook"
      links << [t("integrations.resources.room_calendar"), calendar_bookings_path]
      links << [t("integrations.resources.professionals"), professionals_path]
    when "google_sheets", "notion"
      links << [t("integrations.resources.reports"), reports_path]
      links << [t("integrations.resources.invoices"), invoices_path]
    when "twilio"
      links << [t("integrations.resources.patients"), patients_path]
      links << [t("integrations.resources.waitlist"), waitlist_entries_path]
    else
      links << [t("integrations.resources.api_keys"), api_keys_path]
      links << [t("integrations.resources.bookings"), bookings_path]
      links << [t("integrations.resources.invoices"), invoices_path]
      links << [t("integrations.resources.tickets"), tickets_path]
    end
    links
  end
end
