require "test_helper"

class IntegrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "int-ad-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    sign_in @admin
    ClinicIntegration.ensure_catalog!
  end

  test "saves n8n webhook settings" do
    post integrations_path, params: {
      clinic_integration: {
        kind: "n8n",
        name: "n8n",
        webhook_url: "https://n8n.example.com/webhook/medwork-hub",
        api_base_url: "https://n8n.example.com"
      }
    }
    n8n = ClinicIntegration.find_by!(kind: "n8n")
    assert_redirected_to integration_path(n8n)
    assert n8n.connected?
    assert_equal "https://n8n.example.com/webhook/medwork-hub", n8n.webhook_url
  end

  test "admin lists clinic integrations and catalog" do
    get integrations_path
    assert_response :success
    assert_match "SMTP", response.body
    assert_match "PIX", response.body
    assert_match "WhatsApp", response.body
    assert_match "Slack", response.body
    assert_match "Make", response.body
    assert_match "Nova integração", response.body
  end

  test "creates edits and deletes an optional app" do
    post integrations_path, params: {
      clinic_integration: { kind: "slack", name: "Slack recepção", channel: "#recepcao", enabled: "1" }
    }
    slack = ClinicIntegration.find_by!(kind: "slack")
    assert_redirected_to integration_path(slack)

    patch integration_path(slack), params: {
      clinic_integration: { name: "Slack financeiro", notes: "Avisos de fatura", webhook_url: "https://hooks.slack.com/example" }
    }
    assert_redirected_to integration_path(slack)
    slack.reload
    assert_equal "Slack financeiro", slack.name
    assert_equal "Avisos de fatura", slack.notes
    assert slack.connected?

    delete integration_path(slack)
    assert_redirected_to integrations_path
    refute ClinicIntegration.exists?(slack.id)
  end

  test "connects an optional app and disconnects it" do
    integration = ClinicIntegration.create!(kind: "google_calendar", name: "Google Calendar", enabled: false)
    patch connect_integration_path(integration)
    assert_redirected_to integrations_path
    assert integration.reload.connected?

    patch disconnect_integration_path(integration)
    assert_redirected_to integrations_path
    refute integration.reload.connected?
  end

  test "smtp connect sends the admin to mail settings" do
    patch connect_integration_path("smtp")
    assert_redirected_to settings_path(edit: "mail")
  end

  test "calendar cannot be disconnected or deleted" do
    patch disconnect_integration_path("calendar")
    assert_redirected_to integrations_path
    follow_redirect!
    assert_match "não pode ser desligada", response.body

    delete integration_path("calendar")
    assert_redirected_to integrations_path
    assert ClinicIntegration.exists?(provider: "calendar")
  end

  test "professional cannot open integrations" do
    pro = User.create!(name: "Pro", email: "int-pro-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    sign_in pro
    get integrations_path
    assert_redirected_to rooms_path
  end
end
