class OutboundEmailsController < ApplicationController
  before_action :require_admin
  before_action :set_email, only: %i[show preview resend forward download destroy]

  INDEX_COLUMNS = %i[id to_address subject action_name mailer status error_message sent_at user_id].freeze

  def index
    ProcessEmailBounces.call
    scope = OutboundEmail.newest.select(*INDEX_COLUMNS).preload(:user)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(action_name: params[:kind]) if params[:kind].present?
    if params[:q].present?
      scope = scope.where(
        "to_address ILIKE :q OR subject ILIKE :q OR action_name ILIKE :q OR error_message ILIKE :q",
        q: like_query
      )
    end

    @kinds = OutboundEmail.distinct.order(:action_name).pluck(:action_name).compact
    @emails = paginate(scope, per: 24)
  end

  def show
    @inbox = OutboundEmail.newest.select(*INDEX_COLUMNS).limit(18)
  end

  def preview
    render layout: false
  end

  def edit_welcome
    @setting = Setting.current
    @setting.welcome_email_subject = WelcomeEmailTemplate::DEFAULT_SUBJECT if @setting.welcome_email_subject.blank?
    @setting.welcome_email_html = WelcomeEmailTemplate::DEFAULT_HTML if @setting.welcome_email_html.blank?
    @preview_html = WelcomeEmailTemplate.html_for(setting: @setting, **WelcomeEmailTemplate.preview_vars(@setting))
    @preview_subject = WelcomeEmailTemplate.subject_for(setting: @setting, **WelcomeEmailTemplate.preview_vars(@setting))
  end

  def update_welcome
    @setting = Setting.current
    if @setting.update(welcome_params)
      redirect_to edit_welcome_outbound_emails_path, notice: "Welcome email saved."
    else
      @preview_html = WelcomeEmailTemplate.html_for(setting: @setting, **WelcomeEmailTemplate.preview_vars(@setting))
      @preview_subject = WelcomeEmailTemplate.subject_for(setting: @setting, **WelcomeEmailTemplate.preview_vars(@setting))
      render :edit_welcome, status: :unprocessable_entity
    end
  end

  def new
    @to = params[:to].presence || current_user.email
    @subject = params[:subject]
    @body = params[:body]
  end

  def create
    to = params[:to].to_s.strip
    subject = params[:subject].to_s.strip
    body = params[:body].to_s.strip
    if to.blank? || body.blank?
      @to = to
      @subject = subject
      @body = body
      flash.now[:alert] = "To and message are required."
      render :new, status: :unprocessable_entity
      return
    end

    OutboundMailer.compose(to: to, subject: subject, body: body).deliver_now
    redirect_to outbound_emails_path, notice: "Email sent to #{to}."
  rescue StandardError => e
    record_failure_message(to: to, subject: subject, body: body, error: e)
    redirect_to new_outbound_email_path(to: to, subject: subject, body: body), alert: "Send failed: #{e.message}"
  end

  def resend
    deliver_copy(@email)
    redirect_to outbound_emails_path, notice: "Email resent to #{@email.to_address}."
  rescue StandardError => e
    record_failure(@email, e, to: @email.to_address)
    redirect_to outbound_emails_path, alert: "Resend failed: #{e.message}"
  end

  def forward
    to = params[:to].to_s.strip
    if to.blank?
      redirect_to outbound_email_path(@email), alert: "Enter an email to forward to."
      return
    end

    deliver_copy(@email, to: to)
    redirect_to outbound_emails_path, notice: "Email forwarded to #{to}."
  rescue StandardError => e
    record_failure(@email, e, to: to)
    redirect_to outbound_email_path(@email), alert: "Forward failed: #{e.message}"
  end

  def download
    html = @email.body_html.presence || "<pre>#{ERB::Util.html_escape(@email.body_text.to_s)}</pre>"
    filename = "email-#{@email.id}-#{(@email.subject.presence || "message").parameterize.truncate(40, omission: "")}.html"
    send_data html, filename: filename, type: "text/html; charset=utf-8", disposition: "attachment"
  end

  def bulk
    emails = OutboundEmail.where(id: Array(params[:email_ids]))
    case params[:bulk_action]
    when "resend"
      ok = 0
      fail = 0
      emails.find_each do |email|
        deliver_copy(email)
        ok += 1
      rescue StandardError => e
        record_failure(email, e, to: email.to_address)
        fail += 1
      end
      redirect_to outbound_emails_path, notice: "Resent #{ok} email(s).#{fail.positive? ? " #{fail} failed." : ""}"
    when "delete"
      count = emails.count
      emails.destroy_all
      redirect_to outbound_emails_path, notice: "Removed #{count} email(s) from the log."
    else
      redirect_to outbound_emails_path, alert: "Choose a bulk action."
    end
  end

  def destroy
    @email.destroy
    redirect_to outbound_emails_path, notice: "Email removed from the log."
  end

  private

  def set_email
    @email = OutboundEmail.find(params[:id])
  end

  def welcome_params
    params.require(:setting).permit(:welcome_email_subject, :welcome_email_html)
  end

  def deliver_copy(email, to: nil)
    OutboundMailer.replay(email, to: to).deliver_now
  end

  def record_failure(email, error, to:)
    record_failure_message(to: to, subject: email.subject, body: email.body_text, error: error, from: email.from_address)
  end

  def record_failure_message(to:, subject:, body:, error:, from: nil)
    OutboundEmail.record_from!(
      Mail.new(to: to, from: from.presence || MailerConfig.from_address, subject: subject, body: body),
      mailer: "OutboundMailer",
      action_name: "replay",
      status: "failed",
      error: error.message
    )
  end
end
