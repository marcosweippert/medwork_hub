require "test_helper"

class NotifyTicketTest < ActiveSupport::TestCase
  setup do
    @admin = User.create!(name: "Admin", email: "nt-admin-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    @staff = User.create!(name: "Staff", email: "nt-staff-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    @user = User.create!(name: "Dra. Ana", email: "nt-pro-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
  end

  test "opening a ticket notifies clinic staff" do
    ticket = Ticket.create!(user: @user, subject: "PIX", body: "Não caiu", priority: "medium", category: "billing")

    assert_equal 2, Notification.where(kind: "ticket_opened", notifiable: ticket).count
    assert_equal [@admin.id, @staff.id].sort, Notification.where(notifiable: ticket).pluck(:user_id).sort
    assert_equal 0, @user.notifications.count
  end

  test "staff public reply notifies the requester" do
    ticket = Ticket.create!(user: @user, subject: "Sala", body: "Fria", priority: "low", category: "rooms")
    TicketComment.create!(ticket: ticket, user: @admin, body: "Vamos ver", internal: false)

    note = @user.notifications.find_by(kind: "ticket_message")
    assert_not_nil note
    assert_equal "Sala", note.body
  end

  test "requester reply notifies staff and internal notes stay off the requester" do
    ticket = Ticket.create!(user: @user, subject: "Agenda", body: "Horário", priority: "low", category: "bookings")
    TicketComment.create!(ticket: ticket, user: @user, body: "Ainda aguardo", internal: false)
    TicketComment.create!(ticket: ticket, user: @admin, body: "Nota interna", internal: true)

    assert @admin.notifications.where(kind: "ticket_message").exists?
    assert_not @user.notifications.where("title LIKE ?", "%interna%").exists?
    assert_equal 0, @user.notifications.where(kind: "ticket_message").count
  end
end
