require "test_helper"

class RoomTest < ActiveSupport::TestCase
  setup do
    Setting.current.update!(sunday_closed: true, saturday_opens_at: 9, saturday_closes_at: 12)
    @room = Room.create!(name: "Consult", capacity: 2, daily_rate: 280, monthly_rate: 4200, hourly_rate: 40, opens_at: 8, closes_at: 18)
  end

  test "open days use room hours and sunday follows the clinic closed flag" do
    friday = Date.new(2026, 8, 28)
    saturday = Date.new(2026, 8, 29)
    sunday = Date.new(2026, 8, 30)

    assert_equal [8, 18], @room.schedule_for(friday)
    assert_equal [8, 18], @room.schedule_for(saturday)
    assert_nil @room.schedule_for(sunday)
    assert_equal 10, @room.working_hours_on(friday)
    assert_equal 10, @room.working_hours_on(saturday)
    assert_equal 0, @room.working_hours_on(sunday)
  end

  test "slot price is half the hourly rate for 30 minute slots" do
    assert_equal 20, @room.slot_price
  end

  test "occupancy is zero on a closed sunday" do
    assert_equal 0, @room.occupancy_on(Date.new(2026, 8, 30))
  end

  test "closed weekdays have no opening hours" do
    @room.update!(closed_weekdays: [5])
    friday = Date.new(2026, 8, 28)

    assert_nil @room.schedule_for(friday)
    assert_equal 0, @room.working_hours_on(friday)
  end

  test "upcoming free days scans the window with a handful of queries" do
    travel_to Time.zone.local(2026, 8, 24, 7, 0, 0) do
      queries = 0
      counter = lambda { |*_args| queries += 1 }
      days = nil
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        days = @room.upcoming_free_days(from: Date.new(2026, 8, 24), limit: 3)
      end

      assert_operator days.size, :>=, 1
      assert_operator queries, :<, 12
    end
  end

  test "paid completed bookings count toward occupancy" do
    friday = Date.new(2026, 8, 28)
    user = User.create!(name: "Pro", email: "occ-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    professional = Professional.create!(user: user, specialty: "Clinic", practice_areas: %w[medicina])
    invoice = Invoice.create!(professional: professional, room: @room, amount: 80, status: "paid", paid_at: friday.in_time_zone)
    Booking.create!(
      professional: professional,
      room: @room,
      invoice: invoice,
      start_time: friday.in_time_zone.change(hour: 8),
      end_time: friday.in_time_zone.change(hour: 10),
      status: "completed",
      billing_type: "hourly",
      amount: 80
    )

    assert_equal 20, @room.occupancy_on(friday)
  end
end
