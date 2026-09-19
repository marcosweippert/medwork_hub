require "test_helper"

class ReminderDispatchJobTest < ActiveSupport::TestCase
  test "expires overdue invoices without sending demo mail" do
    user = User.create!(name: "Pro", email: "job-#{SecureRandom.hex(4)}@medworkhub.com", password: "password", role: "professional")
    professional = Professional.create!(user: user, specialty: "Clinic", practice_areas: %w[medicina])
    invoice = Invoice.create!(professional: professional, amount: 50, status: "open", due_date: Date.yesterday)

    assert_nothing_raised { ReminderDispatchJob.perform_now }
    assert_equal "overdue", invoice.reload.status
  end
end
