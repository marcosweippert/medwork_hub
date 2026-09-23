require "test_helper"

class WaitlistEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "wl-admin-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    @pro_user = User.create!(name: "Dra. Ana", email: "wl-pro-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    @professional = Professional.create!(user: @pro_user, specialty: "Psychology", practice_areas: %w[psicologia_psiquiatria])
    @room = Room.create!(name: "Therapy WL", capacity: 2, daily_rate: 220, monthly_rate: 3300, hourly_rate: 40, opens_at: 8, closes_at: 18, room_types: %w[psicologia_psiquiatria])
    sign_in @admin
  end

  test "filters waitlist by professional and supports bulk cancel" do
    starts = 2.days.from_now.change(hour: 10)
    entry = WaitlistEntry.create!(room: @room, professional: @professional, starts_at: starts, ends_at: starts + 30.minutes, status: "waiting")

    get waitlist_entries_path, params: { professional_id: @professional.id, q: "Ana" }
    assert_response :success
    assert_match "Dra. Ana", response.body

    patch bulk_waitlist_entries_path, params: { ids: [entry.id], bulk_action: "cancel" }
    assert_redirected_to waitlist_entries_path
    assert_equal "cancelled", entry.reload.status
  end
end
