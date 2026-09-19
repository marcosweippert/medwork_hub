require "test_helper"

class CreateReservationTest < ActiveSupport::TestCase
  setup do
    user = User.create!(name: "Dr. Test", email: "res-#{SecureRandom.hex(4)}@example.com", password: "password")
    @professional = Professional.create!(user: user, specialty: "Psychology", license_number: "PSY1", practice_areas: %w[psicologia_psiquiatria])
    @room = Room.create!(name: "Consult", capacity: 2, daily_rate: 280, monthly_rate: 4200, hourly_rate: 40, opens_at: 8, closes_at: 18, room_types: %w[psicologia_psiquiatria])
  end

  test "creates an hourly booking from consecutive 30 minute slots" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      saturday = Date.new(2026, 8, 29)
      slots = [
        Time.zone.local(saturday.year, saturday.month, saturday.day, 9, 0).iso8601,
        Time.zone.local(saturday.year, saturday.month, saturday.day, 9, 30).iso8601
      ]

      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "hourly", slots: slots).call

      assert result.success?, result.error
      booking = result.invoice.bookings.first
      assert_equal 40, result.invoice.amount
      assert_equal 1.hour, booking.end_time - booking.start_time
      assert_equal "hourly", booking.billing_type
    end
  end

  test "rejects sunday slots when the clinic is closed on sunday" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      sunday = Date.new(2026, 8, 30)
      slots = [Time.zone.local(sunday.year, sunday.month, sunday.day, 10, 0).iso8601]

      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "hourly", slots: slots).call

      assert_not result.success?
      assert_match(/opening hours/, result.error)
    end
  end

  test "accepts saturday slots until the room closing time" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      saturday = Date.new(2026, 8, 29)
      slots = [Time.zone.local(saturday.year, saturday.month, saturday.day, 14, 0).iso8601]

      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "hourly", slots: slots).call

      assert result.success?, result.error
    end
  end

  test "rejects slots after the room closing time" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      saturday = Date.new(2026, 8, 29)
      slots = [Time.zone.local(saturday.year, saturday.month, saturday.day, 18, 0).iso8601]

      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "hourly", slots: slots).call

      assert_not result.success?
      assert_match(/opening hours/, result.error)
    end
  end

  test "creates a daily reservation for the full opening hours" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      result = CreateReservation.new(
        room: @room,
        professional: @professional,
        billing_type: "daily",
        day: "2026-08-31"
      ).call

      assert result.success?, result.error
      booking = result.invoice.bookings.first
      assert_equal @room.daily_rate, result.invoice.amount
      assert_equal "daily", booking.billing_type
      assert_equal 8, booking.start_time.hour
      assert_equal 18, booking.end_time.hour
    end
  end

  test "rejects a daily reservation when the day is already taken" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      CreateReservation.new(room: @room, professional: @professional, billing_type: "daily", day: "2026-08-31").call
      other = Professional.create!(
        user: User.create!(name: "Other", email: "other-#{SecureRandom.hex(4)}@example.com", password: "password"),
        specialty: "Psychiatry",
        license_number: "PSI1",
        practice_areas: %w[psicologia_psiquiatria]
      )

      result = CreateReservation.new(room: @room, professional: other, billing_type: "daily", day: "2026-08-31").call

      assert_not result.success?
      assert_match(/fully available/, result.error)
    end
  end

  test "monthly reservation creates one booking per working day" do
    travel_to Time.zone.local(2026, 8, 1, 7, 0, 0) do
      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "monthly", month: "2026-08").call

      assert result.success?, result.error
      days = result.invoice.bookings.map { |booking| booking.start_time.to_date }
      assert_not_includes days, Date.new(2026, 8, 2)
      assert_includes days, Date.new(2026, 8, 3)
      assert days.size > 15
      assert_equal (4200 / 30.0 * 31).round(2), result.invoice.amount
      assert_in_delta 140, result.invoice.bookings.first.amount, 0.01
      assert_match(/Dias restantes/, result.invoice.notes)
      assert_equal [result.invoice.id], result.invoice.bookings.map(&:invoice_id).uniq
      assert result.invoice.bookings.first.recurrence_group_id.present?
    end
  end

  test "monthly reservation prorates remaining days and deducts occupied 30 minute slots" do
    travel_to Time.zone.local(2026, 9, 19, 8, 0, 0) do
      @room.update!(monthly_rate: 3300, opens_at: 8, closes_at: 20)
      other = Professional.create!(
        user: User.create!(name: "Other", email: "occ-#{SecureRandom.hex(4)}@example.com", password: "password"),
        specialty: "Psychology",
        license_number: "OCC1",
        practice_areas: %w[psicologia_psiquiatria]
      )
      taken = Time.zone.local(2026, 9, 21, 10, 0)
      Booking.create!(
        professional: other,
        room: @room,
        start_time: taken,
        end_time: taken + 30.minutes,
        status: "confirmed",
        billing_type: "hourly",
        amount: 20
      )

      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "monthly", month: "2026-09").call

      assert result.success?, result.error
      assert_equal 12, (Date.new(2026, 9, 19)..Date.new(2026, 9, 30)).count
      deduction = (3300 / 30.0 / 12 / 2).round(2)
      expected = ((3300 / 30.0) * 12).round(2) - deduction
      assert_equal expected, result.invoice.amount
      assert_match(/calendário da sala/, result.invoice.notes)
      two_hour = result.invoice.bookings.find { |booking| booking.start_time.to_date == Date.new(2026, 9, 21) && booking.duration_hours == 2 }
      rest = result.invoice.bookings.find { |booking| booking.start_time.to_date == Date.new(2026, 9, 21) && booking.start_time.hour == 10 }
      assert_in_delta 18.33, two_hour.amount, 0.01
      assert two_hour.present?
      assert rest.amount.to_d.positive?
    end
  end

  test "weekly recurrence clones the selected slot" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      monday = Date.new(2026, 8, 31)
      slots = [Time.zone.local(monday.year, monday.month, monday.day, 10, 0).iso8601]

      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "hourly", slots: slots, weeks: 3).call

      assert result.success?, result.error
      assert_equal 3, result.invoice.bookings.count
      starts = result.invoice.bookings.order(:start_time).map(&:start_time)
      assert_equal starts.first + 7.days, starts.second
      assert_equal starts.first + 14.days, starts.third
    end
  end

  test "rejects a professional whose practice area does not match the room type" do
    dentist = Professional.create!(
      user: User.create!(name: "Dentist", email: "den-#{SecureRandom.hex(4)}@example.com", password: "password"),
      specialty: "Dentist",
      license_number: "DEN1",
      practice_areas: %w[odontologia]
    )

    result = CreateReservation.new(
      room: @room,
      professional: dentist,
      billing_type: "hourly",
      slots: [Time.zone.local(2026, 8, 31, 10, 0).iso8601]
    ).call

    assert_not result.success?
    assert_match(/room type/, result.error)
  end

  test "recurring weekday block prevents reservation" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      monday = Date.new(2026, 8, 31)
      RoomBlock.create!(
        room: @room,
        starts_at: monday.in_time_zone.change(hour: 10),
        ends_at: monday.in_time_zone.change(hour: 11),
        reason: "Supervision",
        weekdays: [1]
      )
      slots = [Time.zone.local(monday.year, monday.month, monday.day, 10, 0).iso8601]

      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "hourly", slots: slots).call

      assert_not result.success?
      assert_match(/blocked/, result.error)
    end
  end

  test "room block prevents reservation" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      monday = Date.new(2026, 8, 31)
      RoomBlock.create!(room: @room, starts_at: monday.beginning_of_day, ends_at: monday.end_of_day, reason: "Holiday")
      slots = [Time.zone.local(monday.year, monday.month, monday.day, 10, 0).iso8601]

      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "hourly", slots: slots).call

      assert_not result.success?
      assert_match(/blocked/, result.error)
    end
  end
end
