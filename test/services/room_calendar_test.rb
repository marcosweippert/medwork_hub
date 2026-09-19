require "test_helper"

class RoomCalendarTest < ActiveSupport::TestCase
  setup do
    @room = Room.create!(name: "Consult", capacity: 2, daily_rate: 280, monthly_rate: 4200, hourly_rate: 40, opens_at: 8, closes_at: 18)
    @calendar = RoomCalendar.new(@room, start_date: Date.new(2026, 8, 28))
  end

  test "week starts on sunday" do
    assert_equal Date.new(2026, 8, 23), @calendar.dates.first
    assert_equal Date.new(2026, 8, 29), @calendar.dates.last
    assert @calendar.dates.first.sunday?
  end

  test "slots are 30 minutes" do
    assert_includes @calendar.slot_minutes, 8 * 60
    assert_includes @calendar.slot_minutes, 8 * 60 + 30
    assert_equal 30, @calendar.slot_minutes[1] - @calendar.slot_minutes[0]
  end

  test "saturday and sunday follow the room hours" do
    travel_to Time.zone.local(2026, 8, 22, 7, 0, 0) do
      sunday = Date.new(2026, 8, 23)
      saturday = Date.new(2026, 8, 29)

      assert_equal :free, @calendar.slot_for(sunday, 10 * 60).status
      assert_equal :free, @calendar.slot_for(saturday, 8 * 60).status
      assert_equal :free, @calendar.slot_for(saturday, 14 * 60).status
      assert_equal :closed, @calendar.slot_for(saturday, 18 * 60).status
      assert_equal :free, @calendar.slot_for(Date.new(2026, 8, 28), 8 * 60).status
    end
  end

  test "room block marks slots as blocked" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      friday = Date.new(2026, 8, 28)
      RoomBlock.create!(room: @room, starts_at: friday.in_time_zone.change(hour: 10), ends_at: friday.in_time_zone.change(hour: 12), reason: "Maintenance")

      calendar = RoomCalendar.new(@room, start_date: friday)
      assert_equal :blocked, calendar.slot_for(friday, 10 * 60).status
      assert_equal :free, calendar.slot_for(friday, 9 * 60).status
    end
  end
end
