require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "nc-admin-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    @user = User.create!(name: "Dra. Ana", email: "nc-pro-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    @ticket = Ticket.create!(user: @user, subject: "PIX", body: "Ajuda", priority: "medium", category: "billing")
  end

  test "admin opens unread ticket notification and it is marked read" do
    note = @admin.notifications.find_by!(kind: "ticket_opened")
    sign_in @admin
    get notification_path(note)
    assert_redirected_to ticket_path(@ticket)
    assert_not_nil note.reload.read_at
  end

  test "user cannot open another person's notification" do
    note = @admin.notifications.find_by!(kind: "ticket_opened")
    sign_in @user
    get notification_path(note)
    assert_response :not_found
  end
end
