class AppointmentNote < ApplicationRecord
  include Auditable

  belongs_to :booking
  belongs_to :patient

  validates :body, presence: true
end
