class User < ApplicationRecord
  ROLES = %w[admin staff professional].freeze

  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_one :professional, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_many :assigned_tickets, class_name: "Ticket", foreign_key: :assignee_id, dependent: :nullify
  has_many :notifications, dependent: :destroy
  has_many :api_keys, dependent: :nullify
  accepts_nested_attributes_for :professional

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }, allow_blank: true

  def display_name
    name.presence || email
  end

  def admin?
    role == "admin"
  end

  def staff?
    role == "staff"
  end

  def professional?
    role == "professional"
  end

  def clinic_staff?
    admin? || staff?
  end

  def initials
    display_name.split.map { |part| part[0] }.first(2).join.upcase
  end

  def must_change_password?
    ActiveModel::Type::Boolean.new.cast(must_change_password)
  end
end
