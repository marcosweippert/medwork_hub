class RoomReservationsController < ApplicationController
  def create
    room = accessible_rooms.find(params[:room_id])
    professional = professional_user? ? current_professional : Professional.find_by(id: params[:professional_id])
    result = CreateReservation.new(
      room: room,
      professional: professional,
      billing_type: params[:billing_type],
      slots: params[:slots],
      month: params[:month],
      day: params[:day],
      weeks: params[:weeks]
    ).call

    if result.success?
      redirect_to result.invoice, notice: "Reservation confirmed. An invoice was created for payment."
    else
      redirect_to calendar_room_path(room, date: params[:date]), alert: result.error
    end
  end
end
