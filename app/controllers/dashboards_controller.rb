class DashboardsController < ApplicationController
  before_action :require_clinic_staff

  def index
    rooms = Room.order(:name).to_a
    occupancy = rooms.index_with { |room| room.occupancy_on(Date.current) }

    @metrics = {
      professionals: Professional.count,
      patients: Patient.count,
      bookings: Booking.holding.count,
      rooms: rooms.size
    }
    @occupancy_today = rooms.empty? ? 0 : (occupancy.values.sum / rooms.size.to_f).round
    @upcoming_bookings = Booking.includes(:room, professional: :user).upcoming.limit(6)
    @attention_invoices = Invoice.open_or_overdue.includes(:room, professional: :user).order(due_date: :asc).limit(6)
    @open_tickets = Ticket.open_queue.count
    @breached_tickets = Ticket.breached.count

    month = Time.current.beginning_of_month..Time.current.end_of_month
    received = Invoice.where.not(paid_at: nil).where(paid_at: month).sum(:amount)
    refunded = Invoice.where.not(refunded_at: nil).where(refunded_at: month).sum(:refunded_amount)
    @revenue_month = received.to_d - refunded.to_d
    @open_amount = Invoice.open_or_overdue.sum(:amount)
    @overdue_count = Invoice.where(status: "overdue").count
    @hot_rooms = rooms.sort_by { |room| -occupancy[room].to_i }.first(4).map { |room| [room, occupancy[room].to_i] }
    @recent_payments = Invoice.where.not(paid_at: nil).includes(:room, professional: :user).order(paid_at: :desc).limit(8)
    prev = 1.month.ago.beginning_of_month..1.month.ago.end_of_month
    prev_received = Invoice.where.not(paid_at: nil).where(paid_at: prev).sum(:amount).to_d
    @revenue_delta = prev_received.zero? ? 0 : (((@revenue_month - prev_received) / prev_received) * 100).round(1)
  end
end
