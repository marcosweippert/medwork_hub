require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(name: "Admin", email: "cal-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    sign_in user
    @room = Room.create!(name: "Consult", capacity: 2, daily_rate: 280, monthly_rate: 4200, hourly_rate: 40, opens_at: 8, closes_at: 18)
  end

  test "calendar starts on sunday and exposes 30 minute checkboxes" do
    travel_to Time.zone.local(2026, 8, 22, 7, 0, 0) do
      get calendar_room_path(@room, date: "2026-08-28")
      assert_response :success
      assert_match "23/08", response.body
      assert_match "09:30", response.body
      assert_select "input[name='slots[]']"
    end
  end

  test "index lists occupancy days, rates and a calendar action" do
    get rooms_path
    assert_response :success
    assert_match "Hoje", response.body
    assert_match "Diária", response.body
    assert_match "30 min", response.body
    assert_match "Mensal", response.body
    assert_select "a", text: "Calendário"
  end
end
