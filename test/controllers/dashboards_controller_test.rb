require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Ana Staff", email: "dash-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    sign_in @user
    Room.create!(name: "Consultório 1", capacity: 1, daily_rate: 100, monthly_rate: 1000, hourly_rate: 40, opens_at: 8, closes_at: 18, room_types: %w[psicologia_psiquiatria])
  end

  test "renders the Horizon dashboard without overdue professional notices" do
    pro_user = User.create!(name: "Dr Late", email: "late-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    professional = Professional.create!(user: pro_user, specialty: "Psychology", practice_areas: %w[psicologia_psiquiatria])
    Invoice.create!(professional: professional, amount: 80, status: "overdue", due_date: Date.yesterday)

    get root_path

    assert_response :success
    assert_match "Consultório 1", response.body
    assert_match "Ver faturas", response.body
    assert_match "Chamados abertos", response.body
    assert_no_match "não pode criar novas reservas", response.body
    assert_no_match "cannot create new reservations", response.body
    assert_no_match "Dr Late", response.body
  end
end
