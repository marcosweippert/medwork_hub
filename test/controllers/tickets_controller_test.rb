require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "tk-admin-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    @pro_user = User.create!(name: "Dra. Ana", email: "tk-pro-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    @other_user = User.create!(name: "Dr. Other", email: "tk-other-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
  end

  test "professional opens a ticket that appears in the admin queue with SLA" do
    sign_in @pro_user
    assert_difference "Ticket.count", 1 do
      post tickets_path, params: { ticket: { subject: "Fatura PIX", body: "Pagamento não apareceu", priority: "high", category: "billing" } }
    end
    ticket = Ticket.last
    assert_redirected_to ticket_path(ticket)
    assert_equal @pro_user, ticket.user
    assert_equal "open", ticket.status
    assert_equal 8, ticket.sla_hours

    sign_in @admin
    get tickets_path
    assert_response :success
    assert_match "Fatura PIX", response.body
    assert_match "SLA", response.body
    assert_equal 1, @admin.notifications.unread.count
  end

  test "professional cannot see another user ticket" do
    ticket = Ticket.create!(user: @other_user, subject: "Privado", body: "Segredo", priority: "medium", category: "other")
    sign_in @pro_user
    get ticket_path(ticket)
    assert_response :not_found
  end

  test "staff assigns and replies with an internal note hidden from the requester" do
    ticket = Ticket.create!(user: @pro_user, subject: "Sala fria", body: "Ar-condicionado", priority: "medium", category: "rooms")
    sign_in @admin
    patch ticket_path(ticket), params: { ticket: { status: "in_progress", assignee_id: @admin.id, priority: "medium" } }
    assert_redirected_to ticket_path(ticket)
    assert_equal "in_progress", ticket.reload.status
    assert_equal @admin.id, ticket.assignee_id

    post comment_ticket_path(ticket), params: { ticket_comment: { body: "Vou checar com a manutenção", internal: "1" } }
    assert_redirected_to ticket_path(ticket)

    sign_in @pro_user
    get ticket_path(ticket)
    assert_response :success
    assert_no_match "Vou checar com a manutenção", response.body
  end

  test "requester public reply stays visible and does not set first response" do
    ticket = Ticket.create!(user: @pro_user, subject: "Agenda", body: "Horário", priority: "low", category: "bookings")
    sign_in @pro_user
    post comment_ticket_path(ticket), params: { ticket_comment: { body: "Ainda aguardo", internal: "1" } }
    assert_redirected_to ticket_path(ticket)
    comment = ticket.ticket_comments.last
    assert_equal false, comment.internal
    assert_nil ticket.reload.first_response_at
  end

  test "staff can take a ticket" do
    ticket = Ticket.create!(user: @pro_user, subject: "Ar", body: "Quente", priority: "medium", category: "rooms")
    sign_in @admin
    patch take_ticket_path(ticket)
    assert_redirected_to ticket_path(ticket)
    ticket.reload
    assert_equal @admin.id, ticket.assignee_id
    assert_equal "in_progress", ticket.status
  end

  test "staff bulk resolves selected tickets" do
    ticket = Ticket.create!(user: @pro_user, subject: "PIX", body: "Ajuda", priority: "medium", category: "billing")
    sign_in @admin
    patch bulk_tickets_path, params: { ids: [ticket.id], bulk_action: "resolve" }
    assert_redirected_to tickets_path
    assert_equal "resolved", ticket.reload.status
  end

  test "professional cannot reply after ticket is resolved or closed" do
    ticket = Ticket.create!(user: @pro_user, subject: "Luz", body: "Queimada", priority: "medium", category: "rooms")
    ticket.apply_status!("resolved")
    sign_in @pro_user
    get ticket_path(ticket)
    assert_response :success
    assert_match I18n.t("tickets.locked"), response.body
    assert_select "form.ticket-composer", count: 0

    assert_no_difference "TicketComment.count" do
      post comment_ticket_path(ticket), params: { ticket_comment: { body: "Ainda preciso de ajuda" } }
    end
    assert_redirected_to ticket_path(ticket)

    ticket.apply_status!("closed")
    assert_no_difference "TicketComment.count" do
      post comment_ticket_path(ticket), params: { ticket_comment: { body: "Depois do encerramento" } }
    end
  end
end
