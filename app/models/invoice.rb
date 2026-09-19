class Invoice < ApplicationRecord
  include Auditable

  belongs_to :professional
  belongs_to :room, optional: true
  has_many :bookings, dependent: :nullify

  STATUSES = %w[open paid overdue cancelled refunded].freeze

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }, allow_blank: true

  before_create :assign_pix_txid

  scope :open_or_overdue, -> { where(status: %w[open overdue]) }
  scope :due, -> { where(status: "open").where("due_date < ?", Date.current) }

  def self.expire_overdue!
    due.update_all(status: "overdue", updated_at: Time.current)
  end

  def mark_paid!
    transaction do
      update!(status: "paid", paid_at: Time.current)
      bookings.find_each do |booking|
        conflict = booking.room.bookings.holding.where.not(id: booking.id)
          .where("start_time < ? AND end_time > ?", booking.end_time, booking.start_time)
        booking.update_columns(status: conflict.exists? ? "cancelled" : "confirmed")
      end
    end
    NotifyN8n.event("invoice.paid", {
      id: id,
      amount: amount.to_s,
      professional: professional&.display_name,
      room: room&.name,
      due_date: due_date&.iso8601
    })
    self
  end

  def mark_overdue_if_needed!
    return unless status == "open" && due_date.present? && due_date < Date.current

    update!(status: "overdue")
  end

  def issued_on
    created_at&.to_date || Date.current
  end

  def collected_amount
    return 0 if paid_at.blank?
    return 0 if status.in?(%w[open overdue cancelled])

    amount.to_d - refunded_amount.to_d
  end

  def refunded_amount
    self[:refunded_amount].to_d
  end

  def cancellation_fee
    self[:cancellation_fee].to_d
  end

  def refundable?
    status == "paid" && refunded_amount.to_d < amount.to_d
  end

  def cancellable?
    status.in?(%w[open overdue])
  end

  def payable?
    status.in?(%w[open overdue])
  end

  def net_amount
    amount.to_d - refunded_amount.to_d
  end

  def coverage_start
    bookings.filter_map(&:start_time).min
  end

  def coverage_end
    bookings.filter_map(&:end_time).max
  end

  def billing_type_label
    bookings.map { |booking| booking.billing_type.to_s.titleize }.uniq.join(" / ").presence || "—"
  end

  def slot_count
    bookings.sum do |booking|
      next 0 unless booking.start_time && booking.end_time
      next 1 unless booking.billing_type.to_s == "hourly"

      booking.slot_starts.size
    end
  end

  def slot_lines
    step = Room.slot_minutes.minutes
    bookings.sort_by { |booking| booking.start_time || Time.current }.flat_map do |booking|
      if booking.billing_type.to_s == "hourly" && booking.slot_starts.any?
        share = booking.amount.to_d / [booking.slot_starts.size, 1].max
        booking.slot_starts.map do |start_time|
          {
            booking: booking,
            start: start_time,
            end: start_time + step,
            amount: share,
            status: booking.status,
            cancellable: booking.cancellable? && start_time > Time.current && !status.in?(%w[cancelled refunded])
          }
        end
      else
        [{
          booking: booking,
          start: booking.start_time,
          end: booking.end_time,
          amount: booking.amount,
          status: booking.status,
          cancellable: false
        }]
      end
    end
  end

  def cancel!(reason: nil)
    raise "Paid invoices must be refunded instead of cancelled." unless cancellable?

    released = []
    transaction do
      bookings.live.find_each do |booking|
        booking.update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: reason)
        released << booking
      end
      update!(status: "cancelled", cancelled_at: Time.current, cancellation_reason: reason)
    end
    released.each do |booking|
      WaitlistOffer.call(room: booking.room, starts_at: booking.start_time, ends_at: booking.end_time)
    end
    true
  end

  def pix_code
    setting = Setting.current
    return if setting.pix_key.blank?

    PixPayload.build(
      key: setting.pix_key,
      name: setting.pix_name.presence || setting.clinic_name,
      city: setting.pix_city.presence || "Sao Paulo",
      amount: amount,
      txid: ensure_pix_txid,
      description: "Invoice #{id}"
    )
  end

  def ensure_pix_txid
    return pix_txid if pix_txid.present?

    token = "MW#{id}#{SecureRandom.alphanumeric(8).upcase}"[0, 25]
    update_column(:pix_txid, token) if persisted?
    self.pix_txid = token
    token
  end

  private

  def assign_pix_txid
    self.pix_txid ||= "MW#{SecureRandom.alphanumeric(12).upcase}"[0, 25]
  end
end
