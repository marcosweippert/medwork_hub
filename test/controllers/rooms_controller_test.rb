require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(name: "Admin", email: "cal-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    sign_in user
    @room = Room.create!(name: "Consult", capacity: 2, daily_rate: 280, monthly_rate: 4200, hourly_rate: 40, opens_at: 8, closes_at: 18)
  end

  test "calendar starts on sunday and exposes 30 minute checkboxes" do
    get calendar_room_path(@room, date: "2026-08-28")
    assert_response :success
    assert_match "Sun 23/08", response.body
    assert_match "09:30", response.body
    assert_select "input[name='slots[]']"
  end

  test "index lists occupancy days, rates and a calendar action" do
    get rooms_path
    assert_response :success
    assert_match "Today", response.body
    assert_match "Daily", response.body
    assert_match "30 min", response.body
    assert_match "Monthly", response.body
    assert_select "a", text: "Calendar"
  end
end
