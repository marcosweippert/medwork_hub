require "test_helper"

class TicketCommentTest < ActiveSupport::TestCase
  test "staff public comment registers first response" do
    requester = User.create!(name: "Pro", email: "cmt-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    staff = User.create!(name: "Staff", email: "cmt-st-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    ticket = Ticket.create!(user: requester, subject: "PIX", body: "Ajuda", priority: "medium", category: "billing")

    TicketComment.create!(ticket: ticket, user: staff, body: "Recebemos", internal: false)

    assert ticket.reload.first_response_at.present?
  end

  test "does not allow comments on resolved tickets" do
    requester = User.create!(name: "Pro", email: "cmt-lock-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    ticket = Ticket.create!(user: requester, subject: "PIX", body: "Ajuda", priority: "medium", category: "billing")
    ticket.apply_status!("resolved")

    comment = TicketComment.new(ticket: ticket, user: requester, body: "Oi")
    assert_not comment.valid?
    assert_includes comment.errors[:base], I18n.t("tickets.locked")
  end
end
