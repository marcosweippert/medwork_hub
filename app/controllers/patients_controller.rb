class PatientsController < ApplicationController
  before_action :require_clinic_staff
  before_action :set_patient, only: %i[show edit update destroy]

  def index
    @patients = Patient.includes(professional: :user)
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
    @patient = Patient.new(professional_id: params[:professional_id])
  end

  def create
    @patient = Patient.new(patient_params)
    if @patient.save
      redirect_to @patient, notice: "Patient created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @patient.update(patient_params)
      redirect_to @patient, notice: "Patient updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @patient.destroy
    redirect_to patients_url, notice: "Patient deleted."
  end

  private

  def set_patient
    @patient = Patient.includes(professional: :user).find(params[:id])
  end

  def patient_params
    params.require(:patient).permit(:professional_id, :name, :contact, :history)
  end
end
