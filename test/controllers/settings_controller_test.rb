require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "st-admin-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    Setting.delete_all
    @setting = Setting.create!(clinic_name: "MedWork Hub")
    sign_in @admin
  end

  test "edits a single settings card" do
    get settings_path(edit: "clinic")
    assert_response :success
    assert_select "input[name='setting[clinic_name]']"

    patch settings_path, params: {
      section: "clinic",
      setting: {
        clinic_name: "Clinica Norte",
        clinic_email: "norte@example.com",
        clinic_phone: "",
        currency: "BRL",
        slot_minutes: 30,
        week_starts_on: "sunday"
      }
    }
    assert_redirected_to settings_path
    follow_redirect!
    assert_match "Clinica Norte", response.body
  end

  test "uploads a clinic logo" do
    get settings_path(edit: "clinic")
    assert_select "input[type=file][name='setting[logo]']"

    file = Tempfile.new(["logo", ".png"])
    file.binmode
    file.write("\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82")
    file.rewind

    patch settings_path, params: {
      section: "clinic",
      setting: {
        clinic_name: "MedWork Hub",
        clinic_email: "",
        clinic_phone: "",
        currency: "BRL",
        slot_minutes: 30,
        week_starts_on: "sunday",
        logo: Rack::Test::UploadedFile.new(file.path, "image/png")
      }
    }
    assert_redirected_to settings_path
    assert @setting.reload.logo.attached?
  ensure
    file&.close!
  end

  test "saves ticket SLA on the tickets card" do
    get settings_path(edit: "tickets")
    assert_response :success

    patch settings_path, params: {
      section: "tickets",
      setting: {
        ticket_sla_urgent: 2,
        ticket_sla_high: 6,
        ticket_sla_medium: 18,
        ticket_sla_low: 48,
        ticket_sla_warn_hours: 3,
        ticket_default_priority: "high",
        ticket_notify_staff: "1",
        ticket_notify_requester: "1",
        ticket_auto_close_days: 7
      }
    }
    assert_redirected_to settings_path
    follow_redirect!
    assert_match "2h", response.body
    assert_match "7 dias", response.body
  end
end
