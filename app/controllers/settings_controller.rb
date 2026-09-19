class SettingsController < ApplicationController
  SECTIONS = {
    "clinic" => %i[clinic_name clinic_email clinic_phone currency slot_minutes week_starts_on logo],
    "policy" => %i[free_cancel_hours late_cancel_percent started_cancel_percent saturday_opens_at saturday_closes_at sunday_closed],
    "mail" => %i[smtp_address smtp_port smtp_domain smtp_username smtp_authentication smtp_enable_starttls mailer_from mailer_host mailer_port mailer_protocol],
    "pix" => %i[pix_key pix_name pix_city whatsapp_phone],
    "tickets" => %i[
      ticket_sla_urgent ticket_sla_high ticket_sla_medium ticket_sla_low ticket_sla_warn_hours
      ticket_default_priority ticket_notify_staff ticket_notify_requester ticket_default_assignee_id ticket_auto_close_days
    ]
  }.freeze

  before_action :require_admin
  before_action :set_setting

  def show
    @edit_section = params[:edit].to_s
    @edit_section = nil unless SECTIONS.key?(@edit_section)
    hydrate_smtp_defaults if @edit_section == "mail"
  end

  def edit
    redirect_to settings_path(edit: params[:section].presence || "clinic")
  end

  def update
    @edit_section = params[:section].to_s
    @edit_section = "clinic" unless SECTIONS.key?(@edit_section)
    attrs = section_params(@edit_section)
    attrs[:ticket_default_assignee_id] = nil if attrs[:ticket_default_assignee_id].blank?
    attrs.delete(:logo) if attrs[:logo].blank?

    if @setting.update(attrs)
      if @edit_section == "clinic" && params[:remove_logo] == "1" && params.dig(:setting, :logo).blank?
        @setting.logo.purge
      end
      if @edit_section == "mail"
        @setting.assign_smtp_password(params.dig(:setting, :smtp_password))
        @setting.save!
        @setting.sync_env_file!
        MailerConfig.reload!
      end
      redirect_to settings_path, notice: t("settings.saved")
    else
      hydrate_smtp_defaults if @edit_section == "mail"
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_setting
    @setting = Setting.current
  end

  def hydrate_smtp_defaults
    @setting.smtp_address = MailerConfig.address if @setting.smtp_address.blank?
    @setting.smtp_port = MailerConfig.port if @setting.smtp_port.blank?
    @setting.smtp_domain = MailerConfig.domain if @setting.smtp_domain.blank?
    @setting.smtp_username = MailerConfig.username if @setting.smtp_username.blank?
    @setting.smtp_authentication = MailerConfig.authentication.to_s if @setting.smtp_authentication.blank?
    @setting.mailer_from = MailerConfig.from_address if @setting.mailer_from.blank?
    @setting.mailer_host = MailerConfig.url_options[:host] if @setting.mailer_host.blank?
    @setting.mailer_port = MailerConfig.url_options[:port] if @setting.mailer_port.blank?
    @setting.mailer_protocol = MailerConfig.url_options[:protocol] if @setting.mailer_protocol.blank?
  end

  def section_params(section)
    allowed = SECTIONS.fetch(section)
    params.require(:setting).permit(*allowed)
  end
end
