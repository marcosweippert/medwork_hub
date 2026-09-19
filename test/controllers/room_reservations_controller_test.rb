require "test_helper"

class RoomReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    admin = User.create!(name: "Admin", email: "adm-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    sign_in admin
    user = User.create!(name: "Dr. Test", email: "book-#{SecureRandom.hex(4)}@example.com", password: "password")
    @professional = Professional.create!(user: user, specialty: "Psychology", license_number: "PSY1", practice_areas: %w[psicologia_psiquiatria])
    @room = Room.create!(name: "Consult", capacity: 2, daily_rate: 280, monthly_rate: 4200, hourly_rate: 40, opens_at: 8, closes_at: 18, room_types: %w[psicologia_psiquiatria])
  end

  test "creates a reservation from selected 30 minute slots" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      saturday = Date.new(2026, 8, 29)
      slot = Time.zone.local(saturday.year, saturday.month, saturday.day, 9, 0)

      assert_difference "Booking.count" => 1, "Invoice.count" => 1 do
        post room_reservations_path(@room), params: {
          professional_id: @professional.id,
          billing_type: "hourly",
          date: "2026-08-23",
          slots: [slot.iso8601]
        }
      end

      invoice = Invoice.order(:id).last
      assert_redirected_to invoice
      assert_equal 20, invoice.amount
    end
  end

  test "redirects back when no slots are selected" do
    post room_reservations_path(@room), params: {
      professional_id: @professional.id,
      billing_type: "hourly",
      date: "2026-08-28"
    }
    assert_redirected_to calendar_room_path(@room, date: "2026-08-28")
    follow_redirect!
    assert_match "Select at least one available slot", response.body
  end
end
