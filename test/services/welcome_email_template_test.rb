require "test_helper"

class WelcomeEmailTemplateTest < ActiveSupport::TestCase
  test "interpolates placeholders" do
    html = WelcomeEmailTemplate.interpolate("Olá {{name}} ({{email}})", name: "Marcos", email: "a@b.com")
    assert_equal "Olá Marcos (a@b.com)", html
  end

  test "falls back to default subject" do
    setting = Setting.current
    setting.update!(welcome_email_subject: nil)
    subject = WelcomeEmailTemplate.subject_for(setting: setting, clinic: "MedWork Hub")
    assert_includes subject, "MedWork Hub"
  end
end
