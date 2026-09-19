require "test_helper"

class ProfessionalAccessTest < ActionDispatch::IntegrationTest
  setup do
    @pro_user = User.create!(name: "Dra. Ana", email: "ana-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    @professional = Professional.create!(user: @pro_user, specialty: "Psychology", practice_areas: %w[psicologia_psiquiatria])
    @other_user = User.create!(name: "Dr. Other", email: "other-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    @other = Professional.create!(user: @other_user, specialty: "Dentistry", practice_areas: %w[odontologia])
    @psy_room = Room.create!(name: "Therapy", capacity: 2, daily_rate: 220, monthly_rate: 3300, hourly_rate: 40, opens_at: 8, closes_at: 18, room_types: %w[psicologia_psiquiatria])
    @dental_room = Room.create!(name: "Dental", capacity: 1, daily_rate: 450, monthly_rate: 6800, hourly_rate: 55, opens_at: 8, closes_at: 18, room_types: %w[odontologia])
    @own_invoice = Invoice.create!(professional: @professional, room: @psy_room, amount: 80, status: "open", due_date: Date.current)
    @other_invoice = Invoice.create!(professional: @other, room: @dental_room, amount: 90, status: "open", due_date: Date.current)
    sign_in @pro_user
  end

  test "home and dashboard are blocked" do
    get root_path
    assert_redirected_to rooms_path
    get professionals_path
    assert_redirected_to rooms_path
  end

  test "rooms index lists only matching room types" do
    get rooms_path
    assert_response :success
    assert_match "Therapy", response.body
    assert_no_match "Dental", response.body
    assert_no_match "New room", response.body
  end

  test "cannot open a room of another type" do
    get calendar_room_path(@dental_room)
    assert_response :not_found
  end

  test "calendar locks the logged professional" do
    get calendar_room_path(@psy_room)
    assert_response :success
    assert_select "input[type=hidden][name=professional_id][value=?]", @professional.id.to_s
    assert_select "select[name=professional_id]", count: 0
    assert_match @professional.display_name, response.body
  end

  test "cannot mark invoice paid or cancel slots" do
    patch pay_invoice_path(@own_invoice)
    assert_redirected_to rooms_path
    assert_equal "open", @own_invoice.reload.status

    patch cancel_slots_invoice_path(@own_invoice), params: { slot_starts: ["2026-09-20T10:00:00"] }
    assert_redirected_to rooms_path
  end

  test "can view own invoices but not another professional" do
    get invoices_path
    assert_response :success
    assert_match @own_invoice.id.to_s.rjust(4, "0"), response.body
    assert_no_match @other_invoice.id.to_s.rjust(4, "0"), response.body

    get invoice_path(@own_invoice)
    assert_response :success
    assert_no_match "Mark paid", response.body
    assert_no_match "Cancel selected times", response.body

    get invoice_path(@other_invoice)
    assert_response :not_found
  end

  test "waitlist lists only the logged professional" do
    WaitlistEntry.create!(room: @psy_room, professional: @professional, starts_at: 1.day.from_now.change(hour: 10), ends_at: 1.day.from_now.change(hour: 10, min: 30), status: "waiting")
    WaitlistEntry.create!(room: @dental_room, professional: @other, starts_at: 1.day.from_now.change(hour: 11), ends_at: 1.day.from_now.change(hour: 11, min: 30), status: "waiting")

    get waitlist_entries_path
    assert_response :success
    assert_match @professional.display_name, response.body
    assert_no_match @other.display_name, response.body
  end
end
