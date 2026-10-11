class PatientsController < ApplicationController
  before_action :set_patient, only: %i[show edit update destroy export]

  def index
    @patients = Patient.includes(professional: :user)
    @patients = scope_to_current_professional(@patients)
    @patients = @patients.where(professional_id: params[:professional_id]) if params[:professional_id].present?
    if params[:q].present?
      @patients = @patients.left_joins(professional: :user).where("patients.name ILIKE :q OR patients.contact ILIKE :q OR users.name ILIKE :q", q: like_query)
    end
    @patients = paginate(@patients.order(:name), per: 20)
  end

  def show
    @notes = @patient.appointment_notes.includes(booking: :room).order(created_at: :desc)
  end

  def new
    @patient = Patient.new(professional_id: default_professional_id)
  end

  def create
    @patient = Patient.new(patient_params)
    if @patient.save
      redirect_to @patient, notice: t("flash.patients.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @patient.update(patient_params)
      redirect_to @patient, notice: t("flash.patients.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @patient.destroy
    redirect_to patients_url, notice: t("flash.patients.deleted")
  end

  def export
    send_data JSON.pretty_generate(export_payload),
              filename: "paciente-#{@patient.id}.json",
              type: "application/json",
              disposition: "attachment"
  end

  private

  def set_patient
    @patient = scope_to_current_professional(Patient.includes(professional: :user)).find(params[:id])
  end

  def default_professional_id
    return current_professional.id if professional_user? && current_professional

    params[:professional_id]
  end

  def patient_params
    permitted = params.require(:patient).permit(:professional_id, :name, :contact, :history)
    permitted[:professional_id] = current_professional.id if professional_user? && current_professional
    permitted
  end

  def export_payload
    {
      exported_at: Time.current.iso8601,
      patient: @patient.as_json(only: %i[id name contact history created_at updated_at]),
      professional: @patient.professional.display_name,
      bookings: @patient.bookings.order(:start_time).map { |booking|
        booking.as_json(only: %i[id status start_time end_time room_id])
      },
      notes: @patient.appointment_notes.order(:created_at).map { |note|
        note.as_json(only: %i[id body booking_id created_at])
      }
    }
  end
end
