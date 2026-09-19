require "test_helper"

class RoomTest < ActiveSupport::TestCase
  setup do
    @room = Room.create!(name: "Consult", capacity: 2, daily_rate: 280, monthly_rate: 4200, hourly_rate: 40, opens_at: 8, closes_at: 18)
  end

  test "every weekday uses the room opening hours" do
    friday = Date.new(2026, 8, 28)
    saturday = Date.new(2026, 8, 29)
    sunday = Date.new(2026, 8, 30)

    assert_equal [8, 18], @room.schedule_for(friday)
    assert_equal [8, 18], @room.schedule_for(saturday)
    assert_equal [8, 18], @room.schedule_for(sunday)
    assert_equal 10, @room.working_hours_on(friday)
    assert_equal 10, @room.working_hours_on(saturday)
    assert_equal 10, @room.working_hours_on(sunday)
  end

  test "slot price is half the hourly rate for 30 minute slots" do
    assert_equal 20, @room.slot_price
  end

  test "occupancy is calculated on sunday when the room is open" do
    assert_equal 0, @room.occupancy_on(Date.new(2026, 8, 30))
  end

  test "closed weekdays have no opening hours" do
    @room.update!(closed_weekdays: [5])
    friday = Date.new(2026, 8, 28)

    assert_nil @room.schedule_for(friday)
    assert_equal 0, @room.working_hours_on(friday)
  end
end
