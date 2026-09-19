class SettingsController < ApplicationController
  before_action :require_admin
  before_action :set_setting

  def show; end

  def edit
    hydrate_smtp_defaults
  end

  def update
    if @setting.update(setting_params.except(:smtp_password))
      @setting.assign_smtp_password(params.dig(:setting, :smtp_password))
      @setting.save!
      @setting.sync_env_file!
      MailerConfig.reload!
      redirect_to settings_path, notice: "Settings saved."
    else
      hydrate_smtp_defaults
      render :edit, status: :unprocessable_entity
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

  def setting_params
    params.require(:setting).permit(
      :clinic_name, :clinic_email, :clinic_phone, :currency, :slot_minutes,
      :free_cancel_hours, :late_cancel_percent, :started_cancel_percent, :week_starts_on,
      :pix_key, :pix_name, :pix_city, :whatsapp_phone,
      :smtp_address, :smtp_port, :smtp_domain, :smtp_username, :smtp_authentication,
      :smtp_enable_starttls, :mailer_from, :mailer_host, :mailer_port, :mailer_protocol
    )
  end
end
