require "test_helper"

class CancelReservationTest < ActiveSupport::TestCase
  setup do
    user = User.create!(name: "Dr. Cancel", email: "cancel-#{SecureRandom.hex(4)}@example.com", password: "password")
    @professional = Professional.create!(user: user, specialty: "Psychology", license_number: "CAN1", practice_areas: %w[psicologia_psiquiatria])
    @room = Room.create!(name: "Consult", capacity: 2, daily_rate: 280, monthly_rate: 3100, hourly_rate: 40, opens_at: 8, closes_at: 18, room_types: %w[psicologia_psiquiatria])
  end

  test "cancelling a paid daily booking refunds the invoice" do
    travel_to Time.zone.local(2026, 8, 28, 7, 0, 0) do
      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "daily", day: "2026-08-31").call
      invoice = result.invoice
      invoice.mark_paid!
      booking = invoice.bookings.first

      cancel = CancelReservation.new(booking: booking.reload, reason: "Client request").call

      assert cancel.success?, cancel.error
      invoice.reload
      assert_equal "refunded", invoice.status
      assert_equal invoice.amount, invoice.refunded_amount
      assert_equal "cancelled", booking.reload.status
    end
  end

  test "monthly reservation creates a single invoice and cancel refunds unused days plus one slot" do
    travel_to Time.zone.local(2026, 8, 10, 10, 0, 0) do
      result = CreateReservation.new(room: @room, professional: @professional, billing_type: "monthly", month: "2026-08").call
      invoice = result.invoice
      assert_equal 1, Invoice.where(professional: @professional, room: @room).count
      invoice.mark_paid!
      booking = invoice.bookings.order(:start_time).first
      settlement = ClinicPolicy.monthly_settlement(booking)

      cancel = CancelReservation.new(booking: booking.reload).call

      assert cancel.success?, cancel.error
      invoice.reload
      assert_equal "refunded", invoice.status
      assert_equal settlement[:refund], invoice.refunded_amount
      assert_equal settlement[:fee], invoice.cancellation_fee
      assert invoice.bookings.reload.all? { |item| item.status == "cancelled" }
      assert_equal 0, invoice.bookings.live.count
    end
  end
end
