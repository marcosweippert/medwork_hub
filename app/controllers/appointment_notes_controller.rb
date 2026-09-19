class AppointmentNotesController < ApplicationController
  before_action :set_booking

  def create
    @note = @booking.appointment_notes.new(note_params)
    if @note.save
      @booking.update_column(:patient_id, @note.patient_id) if @booking.patient_id.blank?
      redirect_to @booking, notice: "Appointment note saved."
    else
      redirect_to @booking, alert: @note.errors.full_messages.to_sentence
    end
  end

  def destroy
    @booking.appointment_notes.find(params[:id]).destroy
    redirect_to @booking, notice: "Note removed."
  end

  private

  def set_booking
    @booking = scope_to_current_professional(Booking).find(params[:booking_id])
  end

  def note_params
    params.require(:appointment_note).permit(:patient_id, :body)
  end
end
