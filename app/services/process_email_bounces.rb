require "net/imap"
require "timeout"

class ProcessEmailBounces
  TIMEOUT_SECONDS = 3
  LOOKBACK_DAYS = 14
  CACHE_KEY = "process_email_bounces:last"
  CACHE_TTL = 5.minutes

  Result = Struct.new(:checked, :updated, :error, keyword_init: true)

  def self.call(force: false)
    return Result.new(checked: 0, updated: 0) unless MailerConfig.delivery_method == :smtp
    return Result.new(checked: 0, updated: 0) unless MailerConfig.smtp_configured? && MailerConfig.password_configured?
    return Result.new(checked: 0, updated: 0) unless force || Rails.cache.write(CACHE_KEY, true, expires_in: CACHE_TTL, unless_exist: true)

    new.call
  end

  def self.parse(raw)
    mail = Mail.new(raw)
    blob = [mail.header.to_s, extract_text(mail)].join("\n")
    recipient = header_value(mail, "X-Failed-Recipients").presence ||
                blob[/(?:Final|Original)-Recipient:.*?[;:]\s*<?([^\s>;]+@[^>\s;]+)>?/i, 1]
    message_id = blob[/Original-Message-ID:\s*<?([^>\s]+)>?/i, 1] ||
                 blob[/In-Reply-To:\s*<?([^>\s]+)>?/i, 1]
    diagnostic = blob[/Diagnostic-Code:\s*(.+)/i, 1]&.strip
    smtp_status = blob[/^Status:\s*([0-9.]+)/i, 1]
    reason = [
      smtp_status,
      diagnostic.presence || bounce_phrase(blob)
    ].compact.join(" — ").truncate(500)

    {
      recipient: recipient.to_s.strip.downcase.gsub(/[<>]/, "").presence,
      message_id: message_id.to_s.strip.presence,
      reason: reason.presence || "Delivery failed (bounce received)."
    }
  end

  def call
    return Result.new(checked: 0, updated: 0) unless MailerConfig.delivery_method == :smtp
    return Result.new(checked: 0, updated: 0) unless MailerConfig.smtp_configured? && MailerConfig.password_configured?

    Timeout.timeout(TIMEOUT_SECONDS) { process_inbox }
  rescue StandardError => e
    Rails.logger.warn("Bounce inbox check failed: #{e.class}: #{e.message}")
    Result.new(checked: 0, updated: 0, error: e.message)
  end

  private

  def process_inbox
    updated = 0
    checked = 0
    imap = Net::IMAP.new(imap_host, port: 993, ssl: true)
    begin
      imap.login(MailerConfig.username, MailerConfig.smtp_settings[:password].to_s)
      imap.select("INBOX")
      since = LOOKBACK_DAYS.days.ago.strftime("%d-%b-%Y")
      ids = bounce_ids(imap, since)
      ids.last(40).each do |id|
        fetched = imap.fetch(id, "RFC822")
        raw = fetched&.first&.attr&.[]("RFC822")
        next if raw.blank?

        checked += 1
        updated += 1 if apply_bounce(self.class.parse(raw))
      end
    ensure
      begin
        imap.logout
      rescue StandardError
        nil
      end
      begin
        imap.disconnect
      rescue StandardError
        nil
      end
    end
    Result.new(checked: checked, updated: updated)
  end

  def bounce_ids(imap, since)
    queries = [
      ["SINCE", since, "FROM", "mailer-daemon@googlemail.com"],
      ["SINCE", since, "FROM", "mailer-daemon"],
      ["SINCE", since, "SUBJECT", "Delivery Status Notification"],
      ["SINCE", since, "SUBJECT", "Undeliverable"]
    ]
    queries.flat_map do |query|
      begin
        imap.search(query)
      rescue StandardError
        []
      end
    end.uniq
  end

  def apply_bounce(parsed)
    email = find_email(parsed)
    return false unless email
    return false if email.status == "bounced" && email.error_message == parsed[:reason]

    email.update!(
      status: "bounced",
      error_message: parsed[:reason],
      bounced_at: Time.current
    )
    true
  end

  def find_email(parsed)
    scope = OutboundEmail.where(status: %w[sent bounced]).where("sent_at >= ?", LOOKBACK_DAYS.days.ago)
    if parsed[:message_id].present?
      id = parsed[:message_id]
      found = scope.where("message_id = :id OR message_id = :wrapped", id: id, wrapped: "<#{id}>").first
      return found if found
    end
    return if parsed[:recipient].blank?

    scope.where("LOWER(to_address) = ?", parsed[:recipient]).newest.first
  end

  def imap_host
    address = MailerConfig.address.to_s
    return "imap.gmail.com" if address.include?("gmail") || address.include?("google")

    address.sub(/\Asmtp\./i, "imap.")
  end

  def self.extract_text(mail)
    chunks = []
    chunks << mail.decoded
    mail.all_parts.each do |part|
      chunks << part.decoded
    rescue StandardError
      nil
    end
    chunks.compact.join("\n")
  rescue StandardError
    mail.body.to_s
  end
  private_class_method :extract_text

  def self.header_value(mail, name)
    mail[name]&.to_s
  end
  private_class_method :header_value

  def self.bounce_phrase(blob)
    blob[/(Address not found|doesn't have a .{0,40}account|user unknown|mailbox unavailable|over quota|rejected)/i, 1]
  end
  private_class_method :bounce_phrase
end
