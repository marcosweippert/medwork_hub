class BookingsController < ApplicationController
  before_action :require_clinic_staff, only: %i[edit update destroy cancel reschedule complete]
  before_action :set_booking, only: %i[show edit update destroy cancel reschedule complete]

  def index
    @bookings = Booking.includes(:room, :invoice, professional: :user).order(start_time: :desc)
    @bookings = scope_to_current_professional(@bookings)
    @bookings = @bookings.where(status: params[:status]) if params[:status].present?
    @bookings = @bookings.where(room_id: params[:room_id]) if params[:room_id].present?
    if params[:q].present?
      @bookings = @bookings.left_joins(:room, professional: :user).where("users.name ILIKE :q OR rooms.name ILIKE :q", q: like_query)
    end
    case params[:when]
    when "today"
      @bookings = @bookings.where(start_time: Date.current.all_day)
    when "upcoming"
      @bookings = @bookings.where("start_time >= ?", Time.current).reorder(start_time: :asc)
    end
    @rooms = accessible_rooms
    @bookings = paginate(@bookings, per: 20)
  end

  def show
    @fee = @booking.cancellation_fee
    @refund = @booking.cancellation_refund
    @policy = ClinicPolicy.summary
    @note = AppointmentNote.new(patient_id: @booking.patient_id)
    @patients = @booking.professional.patients.order(:name)
    @notes = @booking.appointment_notes.includes(:patient).order(created_at: :desc)
  end

  def new
    starts_at = Time.zone.parse(params[:start_time].to_s) if params[:start_time].present?
    @booking = Booking.new(
      professional_id: professional_user? ? current_professional&.id : params[:professional_id],
      room_id: params[:room_id],
      start_time: starts_at,
      end_time: starts_at&.+(30.minutes),
      billing_type: starts_at ? "hourly" : nil,
      status: starts_at ? "pending" : nil
    )
    load_booking_form
  end

  def calendar
    load_booking_calendar
    render :calendar, layout: false
  end

  def create
    if params[:slots].present?
      create_from_slots
    else
      @booking = Booking.new(booking_params)
      if @booking.professional&.delinquent?
        @booking.errors.add(:professional, "has overdue invoices and cannot make new reservations")
        load_booking_form
        render :new, status: :unprocessable_entity
      elsif @booking.save
        redirect_back_to @booking, notice: "Booking created successfully."
      else
        load_booking_form
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
    load_booking_form
  end

  def update
    if @booking.update(booking_params)
      redirect_back_to @booking, notice: "Booking updated successfully."
    else
      load_booking_form
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @booking.destroy
    redirect_to bookings_url, notice: "Booking deleted."
  end

  def cancel
    result = CancelReservation.new(booking: @booking, reason: params[:reason]).call
    if result.success?
      message = if result.refund.to_d.positive?
                  "Booking cancelled. Refund #{helpers.number_to_currency(result.refund)}" \
                    "#{result.fee.to_d.positive? ? " · kept #{helpers.number_to_currency(result.fee)}" : ""}."
                elsif result.fee.to_d.positive?
                  "Booking cancelled. Cancellation fee: #{helpers.number_to_currency(result.fee)}."
                else
                  "Booking cancelled."
                end
      if result.offered
        message += " Waitlist: #{result.offered.professional.display_name} was notified."
      end
      redirect_back_to @booking, notice: message
    else
      redirect_back_to @booking, alert: result.error
    end
  end

  def reschedule
    result = RescheduleBooking.new(
      booking: @booking,
      start_time: params[:start_time],
      end_time: params[:end_time]
    ).call
    if result.success?
      redirect_back_to @booking, notice: "Booking rescheduled."
    else
      redirect_back_to @booking, alert: result.error
    end
  end

  def complete
    if @booking.end_time.present? && @booking.end_time <= Time.current && @booking.status != "cancelled"
      @booking.update!(status: "completed")
      redirect_back_to @booking, notice: "Booking marked as completed."
    else
      redirect_back_to @booking, alert: "Only finished live bookings can be completed."
    end
  end

  private

  def set_booking
    @booking = scope_to_current_professional(Booking.includes(:room, :invoice, :patient, :appointment_notes, professional: :user)).find(params[:id])
  end

  def booking_params
    attrs = params.require(:booking).permit(:professional_id, :room_id, :start_time, :end_time, :status, :billing_type, :amount, :patient_id)
    attrs[:professional_id] = current_professional.id if professional_user? && current_professional
    attrs
  end

  def load_booking_form
    @professionals = professional_user? ? Array(current_professional) : Professional.includes(:user, :invoices)
    @rooms = accessible_rooms
    load_booking_calendar if @booking.room_id.present?
  end

  def load_booking_calendar
    @selected_room = accessible_rooms.find_by(id: params[:room_id] || @booking&.room_id)
    requested = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @date = requested.beginning_of_week(:sunday)
    @calendar = RoomCalendar.new(@selected_room, start_date: @date, days: 7) if @selected_room
  rescue Date::Error, ArgumentError
    @date = Date.current.beginning_of_week(:sunday)
    @calendar = RoomCalendar.new(@selected_room, start_date: @date, days: 7) if @selected_room
  end

  def create_from_slots
    professional = if professional_user?
                     current_professional
                   else
                     Professional.find_by(id: params.dig(:booking, :professional_id) || params[:professional_id])
                   end
    room = accessible_rooms.find_by(id: params.dig(:booking, :room_id) || params[:room_id])
    result = CreateReservation.new(
      room: room,
      professional: professional,
      billing_type: params[:billing_type].presence || "hourly",
      slots: params[:slots],
      weeks: params[:weeks]
    ).call

    if result.success?
      redirect_to result.invoice, notice: "Reservation confirmed. An invoice was created for payment."
    else
      @booking = Booking.new(professional: professional, room: room)
      @booking.errors.add(:base, result.error)
      load_booking_form
      render :new, status: :unprocessable_entity
    end
  end
end
