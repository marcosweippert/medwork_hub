class WaitlistEntriesController < ApplicationController
  before_action :set_room, only: %i[index new create]
  before_action :set_entry, only: %i[destroy convert]

  def index
    @entries = if @room
                 @room.waitlist_entries
               else
                 WaitlistEntry.all
               end
    @entries = scope_to_current_professional(@entries)
    @entries = @entries.includes(:room, professional: :user).order(:starts_at)
    @entries = apply_waitlist_filters(@entries)
    @rooms = accessible_rooms
    @professionals = professional_user? ? Array(current_professional) : Professional.includes(:user).joins(:user).order("users.name")
    @entries = paginate(@entries, per: 20)
  end

  def new
    @entry = @room.waitlist_entries.new(
      starts_at: parse_time(params[:starts_at]),
      ends_at: parse_time(params[:ends_at]) || parse_time(params[:starts_at])&.+(Room.slot_minutes.minutes),
      professional_id: professional_user? ? current_professional&.id : params[:professional_id]
    )
    load_waitlist_form
  end

  def create
    attrs = entry_params.merge(status: "waiting")
    attrs[:professional_id] = current_professional.id if professional_user? && current_professional
    @entry = @room.waitlist_entries.new(attrs)
    if @entry.professional&.delinquent?
      @entry.errors.add(:professional, "has overdue invoices")
      load_waitlist_form
      render :new, status: :unprocessable_entity
    elsif @entry.professional && !@entry.professional.can_reserve?(@room)
      @entry.errors.add(:professional, "cannot waitlist this room type")
      load_waitlist_form
      render :new, status: :unprocessable_entity
    elsif @entry.save
      redirect_to calendar_room_path(@room, date: @entry.starts_at), notice: "Added to the waitlist for this slot."
    else
      load_waitlist_form
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    room = @entry.room
    @entry.update!(status: "cancelled")
    redirect_back fallback_location: room_waitlist_entries_path(room), notice: "Waitlist entry cancelled."
  end

  def convert
    result = convert_entry(@entry)
    if result[:ok]
      redirect_to result[:invoice], notice: t("waitlist.reserved")
    else
      redirect_back fallback_location: waitlist_entries_path, alert: result[:error]
    end
  end

  def bulk
    entries = scope_to_current_professional(WaitlistEntry.where(id: Array(params[:ids])))
    case params[:bulk_action]
    when "convert"
      unless clinic_staff?
        redirect_to waitlist_entries_path, alert: t("access.staff_only")
        return
      end
      converted = 0
      entries.find_each do |entry|
        next unless entry.status.in?(%w[waiting offered])

        converted += 1 if convert_entry(entry)[:ok]
      end
      redirect_to waitlist_entries_path, notice: t("waitlist.bulk_reserved", count: converted)
    when "cancel"
      count = entries.where(status: %w[waiting offered]).update_all(status: "cancelled", updated_at: Time.current)
      redirect_to waitlist_entries_path, notice: t("waitlist.bulk_cancelled", count: count)
    else
      redirect_to waitlist_entries_path
    end
  end

  private

  def set_room
    return if params[:room_id].blank?

    @room = accessible_rooms.find(params[:room_id])
  end

  def set_entry
    @entry = scope_to_current_professional(WaitlistEntry).find(params[:id])
  end

  def entry_params
    params.require(:waitlist_entry).permit(:professional_id, :starts_at, :ends_at)
  end

  def load_waitlist_form
    @professionals = if professional_user?
                       Array(current_professional)
                     else
                       Professional.for_room_select(@room)
                     end
  end

  def parse_time(value)
    Time.zone.parse(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end

  def apply_waitlist_filters(entries)
    if params[:status].present?
      entries = entries.where(status: params[:status])
    else
      entries = entries.open
    end
    entries = entries.where(room_id: params[:room_id]) if params[:room_id].present?
    entries = entries.where(professional_id: params[:professional_id]) if params[:professional_id].present?
    from = filter_date(:from)
    to = filter_date(:to)
    entries = entries.where("starts_at >= ?", from.beginning_of_day) if from
    entries = entries.where("starts_at <= ?", to.end_of_day) if to
    if params[:q].present?
      entries = entries.left_joins(:room, professional: :user).where(
        "users.name ILIKE :q OR rooms.name ILIKE :q",
        q: like_query
      )
    end
    entries
  end

  def filter_date(key)
    raw = params[key].to_s.strip
    return if raw.blank?

    Date.parse(raw)
  rescue Date::Error, ArgumentError
    nil
  end

  def convert_entry(entry)
    if entry.professional.delinquent?
      return { ok: false, error: t("waitlist.delinquent") }
    end
    unless entry.professional.can_reserve?(entry.room)
      return { ok: false, error: t("waitlist.incompatible") }
    end

    slots = entry.slot_starts.select do |iso|
      starts_at = Time.zone.parse(iso)
      !entry.room.slot_taken?(starts_at, starts_at + Room.slot_minutes.minutes)
    end
    result = CreateReservation.new(
      room: entry.room,
      professional: entry.professional,
      billing_type: "hourly",
      slots: slots
    ).call
    if result.success?
      entry.update!(status: "booked")
      { ok: true, invoice: result.invoice }
    else
      { ok: false, error: result.error }
    end
  end
end
