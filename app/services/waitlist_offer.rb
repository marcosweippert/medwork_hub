class WaitlistOffer
  def self.call(room:, starts_at:, ends_at:)
    new(room: room, starts_at: starts_at, ends_at: ends_at).call
  end

  def initialize(room:, starts_at:, ends_at:)
    @room = room
    @starts_at = starts_at
    @ends_at = ends_at
  end

  def call
    return if @room.slot_taken?(@starts_at, @ends_at)

    entry = WaitlistEntry.waiting.for_slot(room: @room, starts_at: @starts_at, ends_at: @ends_at).order(:created_at).first
    return if entry.blank?

    entry.update!(status: "offered", notified_at: Time.current)
    begin
      ClinicMailer.waitlist_offer(entry).deliver_now
    rescue StandardError => e
      Rails.logger.warn("Waitlist email failed: #{e.message}")
    end
    entry
  rescue StandardError => e
    Rails.logger.warn("Waitlist offer failed: #{e.message}")
    nil
  end
end
