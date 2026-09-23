class ApiKey < ApplicationRecord
  include Auditable

  belongs_to :user, optional: true

  attr_accessor :raw_token

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true

  scope :newest, -> { order(created_at: :desc) }

  def self.authenticate(raw)
    return if raw.blank?

    digest = digest_for(raw)
    find_by(token_digest: digest, enabled: true)
  end

  def self.digest_for(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end

  def self.generate_token
    "mwh_#{SecureRandom.hex(20)}"
  end

  def assign_new_token
    token = self.class.generate_token
    self.raw_token = token
    self.token_digest = self.class.digest_for(token)
    self.token_prefix = token[0, 12]
    token
  end

  def masked_token
    "#{token_prefix}••••••••"
  end

  def active?
    enabled?
  end

  def touch_usage!
    update_column(:last_used_at, Time.current)
  end

  def audit_details
    changes = previous_changes.except("updated_at", "created_at", "token_digest", "raw_token")
    changes.presence || { "id" => id, "name" => name }
  end
end
