require "test_helper"

class ProcessEmailBouncesTest < ActiveSupport::TestCase
  setup do
    Setting.current
    @email = OutboundEmail.create!(
      to_address: "missing@example.com",
      subject: "Welcome",
      mailer: "ClinicMailer",
      action_name: "welcome",
      status: "sent",
      message_id: "abc123@medworkhub.com",
      sent_at: Time.current
    )
  end

  test "parses gmail delivery status notification" do
    parsed = ProcessEmailBounces.parse(gmail_dsn)

    assert_equal "missing@example.com", parsed[:recipient]
    assert_includes parsed[:reason], "550"
    assert_includes parsed[:reason].downcase, "not exist"
  end

  test "marks matching sent email as bounced with reason" do
    parsed = ProcessEmailBounces.parse(gmail_dsn)
    ProcessEmailBounces.new.send(:apply_bounce, parsed)

    @email.reload
    assert_equal "bounced", @email.status
    assert_predicate @email.error_message, :present?
    assert_predicate @email.bounced_at, :present?
  end

  private

  def gmail_dsn
    <<~MSG
      From: Mail Delivery Subsystem <mailer-daemon@googlemail.com>
      To: marcos.weippert@gmail.com
      Subject: Delivery Status Notification (Failure)
      X-Failed-Recipients: missing@example.com

      ** Address not found **

      The email account that you tried to reach does not exist.

      ------ This is a copy of the message ------
      Content-Type: message/delivery-status

      Final-Recipient: rfc822; missing@example.com
      Action: failed
      Status: 5.1.1
      Diagnostic-Code: smtp; 550-5.1.1 The email account that you tried to reach does not exist.
      Original-Message-ID: <abc123@medworkhub.com>
    MSG
  end
end
