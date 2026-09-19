class Professional < ApplicationRecord
  belongs_to :user
  has_many :bookings, dependent: :destroy
  has_many :patients, dependent: :destroy
  has_many :invoices, dependent: :destroy
  has_many :waitlist_entries, dependent: :destroy

  before_validation :normalize_practice_areas
  validates :practice_areas, presence: { message: "select at least one practice area" }
  validate :practice_areas_are_known

  scope :delinquent, -> { joins(:invoices).where(invoices: { status: "overdue" }).distinct }

  def display_name
    user&.name.presence || user&.email.presence || "Professional ##{id}"
  end

  def delinquent?
    if invoices.loaded?
      invoices.any? { |invoice| invoice.status == "overdue" }
    else
      invoices.where(status: "overdue").exists?
    end
  end

  def contact_phone
    phone.presence
  end

  def overdue_balance
    if invoices.loaded?
      invoices.select { |invoice| invoice.status == "overdue" }.sum { |invoice| invoice.amount.to_d }
    else
      invoices.where(status: "overdue").sum(:amount)
    end
  end

  def allowed_room_types
    Array(practice_areas).flat_map { |key| PracticeArea.room_types_for(key) }.uniq
  end

  def can_reserve?(room)
    return false if room.blank?

    types = Array(room.room_types)
    return false if types.empty? || allowed_room_types.empty?

    (allowed_room_types & types).any?
  end

  def practice_area_labels
    PracticeArea.labels_for(practice_areas)
  end

  private

  def normalize_practice_areas
    self.practice_areas = Array(practice_areas).map(&:presence).compact
    self.practice_areas = PracticeArea.infer_from_specialty(specialty) if practice_areas.empty?
  end

  def practice_areas_are_known
    unknown = Array(practice_areas) - PracticeArea.keys
    errors.add(:practice_areas, "contains an unknown area") if unknown.any?
  end
end
