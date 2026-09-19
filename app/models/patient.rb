class Patient < ApplicationRecord
  belongs_to :professional
  has_many :appointment_notes, dependent: :destroy
  has_many :bookings, dependent: :nullify

  validates :name, presence: true
end
