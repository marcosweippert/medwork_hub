class RoomsController < ApplicationController
  before_action :require_clinic_staff, only: %i[new create edit update destroy]
  before_action :set_room, only: %i[show edit update destroy calendar]

  def index
    @rooms = accessible_rooms
    @rooms = @rooms.where("name ILIKE :q OR equipment ILIKE :q", q: like_query) if params[:q].present?
    @rooms = paginate(@rooms, per: 20)
    @occupancy_days = 6.times.map { |offset| Date.current + offset }
  end

  def availability
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @start_hour = (params[:start_hour].presence || 9).to_i
    @end_hour = (params[:end_hour].presence || 11).to_i
    @end_hour = @start_hour + 1 if @end_hour <= @start_hour
    starts_at = @date.in_time_zone.change(hour: @start_hour)
    ends_at = @date.in_time_zone.change(hour: @end_hour)
    @hours = (7..21).to_a
    @results = accessible_rooms.map do |room|
      open, close = room.schedule_for(@date)
      available = open.present? && starts_at >= @date.in_time_zone.change(hour: open) &&
                  ends_at <= @date.in_time_zone.change(hour: close) &&
                  !room.slot_taken?(starts_at, ends_at)
      { room: room, available: available, occupancy: room.occupancy_on(@date) }
    end
  rescue Date::Error, ArgumentError
    redirect_to availability_rooms_path, alert: "Select a valid date"
  end

  def show
    @upcoming_bookings = @room.bookings.includes(professional: :user).upcoming.limit(8)
    @today_occupancy = @room.occupancy_on(Date.current)
    @blocks = @room.room_blocks.where("ends_at >= ? OR COALESCE(array_length(weekdays, 1), 0) > 0", Time.current).order(:starts_at)
    @clinic_blocks = RoomBlock.where(room_id: nil).where("ends_at >= ? OR COALESCE(array_length(weekdays, 1), 0) > 0", Time.current).order(:starts_at)
    waitlist = @room.waitlist_entries.open.includes(professional: :user).order(:starts_at)
    waitlist = scope_to_current_professional(waitlist)
    @waitlist = waitlist.limit(10)
    @block = RoomBlock.new(starts_at: Date.current.beginning_of_day, ends_at: Date.current.end_of_day)
  end

  def calendar
    requested = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @date = requested.beginning_of_week(:sunday)
    @calendar = RoomCalendar.new(@room, start_date: @date, days: 7)
    @professionals = if professional_user?
                       Array(current_professional)
                     else
                       Professional.includes(:user, :invoices).select { |professional| professional.can_reserve?(@room) }
                     end
    @free_days = @room.upcoming_free_days(from: Date.current, limit: 12)
    waitlist = @room.waitlist_entries.waiting
    waitlist = scope_to_current_professional(waitlist)
    @waitlist_count = waitlist.count
  end

  def new
    @room = Room.new
    @room.room_blocks.build
  end

  def create
    @room = Room.new(room_params)
    if @room.save
      redirect_to @room, notice: "Room created successfully."
    else
      @room.room_blocks.build if @room.room_blocks.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @room.room_blocks.build if @room.room_blocks.none?
  end

  def update
    if @room.update(room_params)
      redirect_to @room, notice: "Room updated successfully."
    else
      @room.room_blocks.build if @room.room_blocks.empty?
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @room.destroy
    redirect_to rooms_url, notice: "Room deleted."
  end

  private

  def set_room
    @room = accessible_rooms.find(params[:id])
  end

  def room_params
    params.require(:room).permit(
      :name, :capacity, :equipment, :daily_rate, :monthly_rate, :hourly_rate, :opens_at, :closes_at, :photo,
      room_types: [], closed_weekdays: [],
      room_blocks_attributes: [:id, :starts_at, :ends_at, :reason, :_destroy, { weekdays: [] }]
    )
  end
end
