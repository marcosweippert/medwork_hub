require "test_helper"

class AuditEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "aud-ad-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    @room = Room.create!(name: "Sala Norte", capacity: 1, daily_rate: 100, monthly_rate: 1500, hourly_rate: 40, opens_at: 8, closes_at: 18, room_types: %w[psicologia_psiquiatria])
    @pro_user = User.create!(name: "Dra. Lia", email: "aud-pro-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    @professional = Professional.create!(user: @pro_user, specialty: "Psychology", practice_areas: %w[psicologia_psiquiatria])
    @invoice = Invoice.create!(professional: @professional, room: @room, amount: 80, status: "open", due_date: Date.current)
    @event = AuditEvent.create!(
      user: @admin,
      action: "invoice.updated",
      auditable: @invoice,
      details: { "status" => %w[open paid], "amount" => ["80.0", "90.0"] }.to_json
    )
    sign_in @admin
  end

  test "index lists who changed what with before and after" do
    get audit_events_path
    assert_response :success
    assert_match "Atualizou fatura", response.body
    assert_match "Dra. Lia", response.body
    assert_match "Status: open → paid", response.body
    assert_match "Baixar Excel", response.body
    refute_match "Export CSV", response.body
  end

  test "exports xlsx instead of csv" do
    get export_audit_events_path
    assert_response :success
    assert_equal Mime[:xlsx].to_s, response.media_type
    assert_match(/auditoria-.*\.xlsx/, response.headers["Content-Disposition"])
    refute_equal "text/csv", response.media_type
  end

  test "professional cannot open the audit log" do
    sign_in @pro_user
    get audit_events_path
    assert_redirected_to rooms_path
  end
end
