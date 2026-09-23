class Ticket < ApplicationRecord
  include Auditable

  STATUSES = %w[open in_progress waiting resolved closed].freeze
  PRIORITIES = %w[low medium high urgent].freeze
  CATEGORIES = %w[billing rooms bookings technical other].freeze
  SLA_HOURS = { "low" => 72, "medium" => 24, "high" => 8, "urgent" => 4 }.freeze
  OPEN_STATUSES = %w[open in_progress waiting].freeze

  belongs_to :user
  belongs_to :assignee, class_name: "User", optional: true
  has_many :ticket_comments, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  validates :subject, :body, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :category, inclusion: { in: CATEGORIES }

  before_validation :assign_sla, on: :create
  before_validation :assign_default_assignee, on: :create
  before_validation :refresh_sla, on: :update
  after_create :notify_opened

  scope :open_queue, -> { where(status: OPEN_STATUSES) }
  scope :breached, -> { open_queue.where("sla_due_at < ?", Time.current) }
  scope :unassigned, -> { open_queue.where(assignee_id: nil) }
  scope :waiting, -> { where(status: "waiting") }

  def self.auto_close_stale!
    days = Setting.current.ticket_auto_close_days.to_i
    return if days <= 0

    where(status: "resolved").where("resolved_at < ?", days.days.ago).find_each do |ticket|
      ticket.apply_status!("closed")
    end
  end

  def open?
    status.in?(OPEN_STATUSES)
  end

  def accepts_replies?
    open?
  end

  def sla_state
    return "done" unless open?
    return "late" if sla_due_at.present? && sla_due_at < Time.current
    return "warn" if sla_due_at.present? && sla_due_at < sla_warn_hours.hours.from_now

    "ok"
  end

  def sla_label
    return "—" if sla_due_at.blank?
    return I18n.t("tickets.sla_met") unless open?

    if sla_due_at < Time.current
      I18n.t("tickets.sla_late", time: sla_due_at.strftime("%d/%m %H:%M"))
    else
      I18n.t("tickets.sla_until", time: sla_due_at.strftime("%d/%m %H:%M"))
    end
  end

  def register_first_response!
    update!(first_response_at: Time.current) if first_response_at.blank?
  end

  def apply_status!(new_status)
    attrs = { status: new_status }
    attrs[:resolved_at] = Time.current if new_status.in?(%w[resolved closed]) && resolved_at.blank?
    attrs[:closed_at] = Time.current if new_status == "closed"
    update!(attrs)
  end

  private

  def assign_default_assignee
    return if assignee_id.present?

    id = Setting.current.ticket_default_assignee_id
    return if id.blank?

    self.assignee_id = id if User.where(id: id, role: %w[admin staff]).exists?
  rescue StandardError
    nil
  end

  def assign_sla
    self.priority = Setting.current.ticket_default_priority.presence || "medium" if priority.blank?
    self.sla_hours = sla_hours_for(priority)
    self.sla_due_at ||= sla_hours.hours.from_now
  end

  def refresh_sla
    return unless will_save_change_to_priority? && open?

    self.sla_hours = sla_hours_for(priority)
    origin = created_at || Time.current
    self.sla_due_at = origin + sla_hours.hours
  end

  def sla_hours_for(priority)
    Setting.current.ticket_sla_hours_for(priority)
  rescue StandardError
    SLA_HOURS.fetch(priority.to_s, 24)
  end

  def sla_warn_hours
    Setting.current.ticket_sla_warn_hours.to_i
  rescue StandardError
    4
  end

  def notify_opened
    NotifyTicket.opened(self)
    NotifyN8n.event("ticket.created", {
      id: id,
      subject: subject,
      priority: priority,
      category: category,
      user: user&.display_name
    })
  rescue StandardError => e
    Rails.logger.warn("Ticket notify failed: #{e.class}: #{e.message}")
  end
end
