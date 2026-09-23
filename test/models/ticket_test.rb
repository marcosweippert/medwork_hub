require "test_helper"

class TicketTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Requester", email: "ticket-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
  end

  test "assigns SLA hours from priority on create" do
    ticket = Ticket.create!(user: @user, subject: "PIX", body: "Não caiu", priority: "medium", category: "billing")

    assert_equal 24, ticket.sla_hours
    assert_in_delta 24.hours.from_now, ticket.sla_due_at, 5
    assert_equal "ok", ticket.sla_state
  end

  test "marks SLA as late after due date" do
    ticket = Ticket.create!(user: @user, subject: "Sala", body: "Trava", priority: "high", category: "rooms", sla_due_at: 1.hour.ago)

    assert_equal "late", ticket.sla_state
    assert_includes Ticket.breached, ticket
  end

  test "refreshes SLA when priority changes" do
    ticket = Ticket.create!(user: @user, subject: "Agenda", body: "Horário", priority: "low", category: "bookings")
    ticket.update!(priority: "urgent")

    assert_equal 4, ticket.sla_hours
  end

  test "uses SLA hours configured in settings" do
    Setting.current.update!(ticket_sla_medium: 12)
    ticket = Ticket.create!(user: @user, subject: "PIX", body: "Não caiu", priority: "medium", category: "billing")

    assert_equal 12, ticket.sla_hours
  ensure
    Setting.current.update!(ticket_sla_medium: 24)
  end

  test "assigns the default staff member from settings" do
    staff = User.create!(name: "Fila", email: "fila-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    Setting.current.update!(ticket_default_assignee_id: staff.id)
    ticket = Ticket.create!(user: @user, subject: "PIX", body: "Ajuda", priority: "medium", category: "billing")

    assert_equal staff.id, ticket.assignee_id
  ensure
    Setting.current.update!(ticket_default_assignee_id: nil)
  end

  test "auto-closes resolved tickets after the configured days" do
    Setting.current.update!(ticket_auto_close_days: 1)
    ticket = Ticket.create!(user: @user, subject: "PIX", body: "Ajuda", priority: "low", category: "billing")
    ticket.apply_status!("resolved")
    ticket.update_columns(resolved_at: 2.days.ago)

    Ticket.auto_close_stale!

    assert_equal "closed", ticket.reload.status
  ensure
    Setting.current.update!(ticket_auto_close_days: 0)
  end
end
