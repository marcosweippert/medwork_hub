require "test_helper"

class ProfessionalTest < ActiveSupport::TestCase
  setup do
    @room = Room.create!(name: "Consult Medicina", capacity: 2, daily_rate: 280, monthly_rate: 4200, hourly_rate: 40, opens_at: 8, closes_at: 18, room_types: %w[medicina])
    medic_user = User.create!(name: "Dra. Ana", email: "ana-#{SecureRandom.hex(3)}@example.com", password: "password", role: "professional")
    dental_user = User.create!(name: "Dr. Dent", email: "dent-#{SecureRandom.hex(3)}@example.com", password: "password", role: "professional")
    @medic = Professional.create!(user: medic_user, specialty: "Clinic", practice_areas: %w[medicina])
    Professional.create!(user: dental_user, specialty: "Odonto", practice_areas: %w[odontologia])
  end

  test "for_room_select keeps matching professionals and marks overdue without loading invoices" do
    Invoice.create!(professional: @medic, room: @room, amount: 40, status: "overdue", due_date: Date.yesterday)
    selected = Professional.for_room_select(@room)

    assert_equal ["Dra. Ana"], selected.map(&:display_name)
    assert_predicate selected.first, :delinquent?
  end
end
