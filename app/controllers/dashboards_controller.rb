class DashboardsController < ApplicationController
  before_action :require_clinic_staff

  def index
    @metrics = {
      professionals: Professional.count,
      patients: Patient.count,
      bookings: Booking.holding.count,
      rooms: Room.count
    }

    month = Time.current.beginning_of_month..Time.current.end_of_month
    received = Invoice.where.not(paid_at: nil).where(paid_at: month).sum(:amount)
    refunded = Invoice.where.not(refunded_at: nil).where(refunded_at: month).sum(:refunded_amount)
    @revenue_month = received.to_d - refunded.to_d
    @refunded_month = refunded.to_d
    @open_amount = Invoice.open_or_overdue.sum(:amount)
    @occupancy_today = occupancy_average
    @upcoming_bookings = Booking.includes(:room, professional: :user).upcoming.limit(6)
    @recent_invoices = Invoice.includes(:room, professional: :user).order(created_at: :desc).limit(6)
    @rooms = Room.order(:name)
    @financial_summary = {
      open: Invoice.where(status: "open").count,
      paid: Invoice.where(status: "paid").count,
      overdue: Invoice.where(status: "overdue").count,
      refunded: Invoice.where(status: "refunded").count
    }
    @delinquents = Professional.delinquent.includes(:user)
  end

  private

  def occupancy_average
    rooms = Room.all
    return 0 if rooms.empty?

    (rooms.sum { |room| room.occupancy_on(Date.current) } / rooms.size.to_f).round
  end
end
