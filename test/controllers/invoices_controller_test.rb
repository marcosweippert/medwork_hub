require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Admin", email: "inv-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    sign_in @user
    @pro_user = User.create!(name: "Dr Flow", email: "pro-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    @professional = Professional.create!(user: @pro_user, specialty: "Psychology", practice_areas: %w[psicologia_psiquiatria])
    @invoice = Invoice.create!(professional: @professional, amount: 80, status: "overdue", due_date: Date.current - 1)
    @other = Invoice.create!(professional: @professional, amount: 40, status: "open", due_date: Date.current)
  end

  test "returns to professional after paying from that screen" do
    patch pay_invoice_path(@invoice, return_to: professional_path(@professional))
    assert_redirected_to professional_path(@professional)
    assert_equal "paid", @invoice.reload.status
  end

  test "pays selected invoices in bulk" do
    patch bulk_invoices_path, params: {
      invoice_ids: [@invoice.id, @other.id],
      bulk_action: "pay",
      return_to: invoices_path
    }
    assert_redirected_to invoices_path
    assert_equal "paid", @invoice.reload.status
    assert_equal "paid", @other.reload.status
  end

  test "cancels a paid invoice and refunds according to policy" do
    @other.update!(status: "paid", paid_at: Time.current)
    booking = Booking.create!(
      professional: @professional,
      room: Room.create!(name: "Inv Room", capacity: 1, daily_rate: 100, monthly_rate: 1000, hourly_rate: 40, opens_at: 8, closes_at: 18, room_types: %w[psicologia_psiquiatria]),
      invoice: @other,
      start_time: 2.days.from_now.change(hour: 10),
      end_time: 2.days.from_now.change(hour: 11),
      status: "confirmed",
      billing_type: "hourly",
      amount: 40
    )

    assert_difference -> { @other.reload.refunded_amount.to_d }, 40 do
      patch cancel_invoice_path(@other)
    end
    assert_redirected_to invoice_path(@other)
    assert_equal "refunded", @other.reload.status
    assert_equal "cancelled", booking.reload.status
  end
end
