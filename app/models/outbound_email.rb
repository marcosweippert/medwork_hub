class OutboundEmail < ApplicationRecord
  STATUSES = %w[sent failed bounced].freeze

  belongs_to :user, optional: true

  validates :to_address, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :newest, -> { order(sent_at: :desc, id: :desc) }

  def self.record_from!(message, mailer:, action_name:, status: "sent", error: nil)
    recipients = Array(message.to).join(", ")
    recipient_user = User.find_by(email: Array(message.to).first)

    create!(
      to_address: recipients.presence || "(none)",
      cc: Array(message.cc).join(", ").presence,
      bcc: Array(message.bcc).join(", ").presence,
      from_address: Array(message.from).join(", ").presence || Array(message[:from]&.decoded).join(", ").presence,
      subject: message.subject.to_s,
      mailer: mailer,
      action_name: action_name.to_s,
      status: status,
      body_html: extract_html(message),
      body_text: extract_text(message),
      error_message: error,
      message_id: message.message_id.to_s.presence,
      sent_at: Time.current,
      user: recipient_user
    )
  end

  def kind
    [mailer.to_s.delete_suffix("Mailer"), action_name].reject(&:blank?).join(" · ").presence || "Email"
  end

  def kind_label
    {
      "welcome" => "Welcome",
      "replay" => "Resent",
      "compose" => "Composed",
      "booking_reminder" => "Reminder",
      "overdue_notice" => "Overdue",
      "waitlist_offer" => "Waitlist"
    }[action_name.to_s] || action_name.to_s.humanize.presence || "Email"
  end

  def failed?
    status.in?(%w[failed bounced])
  end

  def bounced?
    status == "bounced"
  end

  def html?
    body_html.present?
  end

  def preview_html
    html = body_html.to_s
    inner = html[/<body[^>]*>(.*?)<\/body>/mi, 1]
    html = inner if inner.present?
    html.gsub(%r{<style\b[^>]*>.*?<\/style>}mi, "")
  end

  def self.extract_html(message)
    part = message.html_part || (message.content_type.to_s.include?("html") ? message : nil)
    part&.decoded.to_s.presence
  rescue StandardError
    nil
  end

  def self.extract_text(message)
    part = message.text_part || (message.content_type.to_s.start_with?("text/plain") ? message : nil)
    part&.decoded.to_s.presence || message.decoded.to_s.presence
  rescue StandardError
    message.body.to_s
  end
end
