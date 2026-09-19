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
    if params[:status].present?
      @entries = @entries.where(status: params[:status])
    else
      @entries = @entries.open
    end
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
    if @entry.professional.delinquent?
      redirect_back fallback_location: waitlist_entries_path, alert: "This professional has overdue invoices and cannot reserve."
      return
    end
    unless @entry.professional.can_reserve?(@entry.room)
      redirect_back fallback_location: waitlist_entries_path, alert: "This professional cannot reserve this room type."
      return
    end

    slots = @entry.slot_starts.select do |iso|
      starts_at = Time.zone.parse(iso)
      !@entry.room.slot_taken?(starts_at, starts_at + Room.slot_minutes.minutes)
    end
    result = CreateReservation.new(
      room: @entry.room,
      professional: @entry.professional,
      billing_type: "hourly",
      slots: slots
    ).call
    if result.success?
      @entry.update!(status: "booked")
      redirect_to result.invoice, notice: "Waitlist slot reserved. An invoice was created."
    else
      redirect_back fallback_location: waitlist_entries_path, alert: result.error
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
                       Professional.includes(:user, :invoices).select { |professional| professional.can_reserve?(@room) }
                     end
  end

  def parse_time(value)
    Time.zone.parse(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end
end
