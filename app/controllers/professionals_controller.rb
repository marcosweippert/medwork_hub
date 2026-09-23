class ProfessionalsController < ApplicationController
  before_action :require_clinic_staff
  before_action :set_professional, only: %i[show edit update destroy]

  def index
    @professionals = Professional.includes(:user, :invoices).left_joins(:user)
    if params[:q].present?
      @professionals = @professionals.where("users.name ILIKE :q OR professionals.specialty ILIKE :q OR professionals.license_number ILIKE :q", q: like_query)
    end
    @professionals = @professionals.delinquent if params[:delinquent] == "1"
    @professionals = paginate(@professionals.order("users.name"), per: 20)
    ids = @professionals.map(&:id)
    @patient_counts = Patient.where(professional_id: ids).group(:professional_id).count
    @booking_counts = Booking.where(professional_id: ids).group(:professional_id).count
  end

  def show
    @overdue_invoices = @professional.invoices.where(status: "overdue").order(:due_date)
    @recent_bookings = @professional.bookings.includes(:room, :invoice).order(start_time: :desc).limit(8)
    @patients = @professional.patients.order(:name)
    @waitlist = @professional.waitlist_entries.open.includes(:room).order(:starts_at).limit(6)
  end

  def new
    @user = User.new(role: "professional")
    @user.build_professional
  end

  def create
    result = CreateUserAccount.call(
      name: user_params[:name],
      email: user_params[:email],
      role: "professional",
      professional: user_params[:professional_attributes]
    )
    @user = result.user
    if result.ok?
      redirect_to @user.professional, notice: t("professionals.created", email: @user.email)
    else
      @user.build_professional if @user.professional.nil?
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @professional.update(professional_params)
      redirect_to @professional, notice: "Professional updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @professional.destroy
    redirect_to professionals_url, notice: "Professional deleted."
  end

  private

  def set_professional
    @professional = Professional.includes(:user, :invoices).find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :name, :email,
      professional_attributes: [:specialty, :license_number, :phone, :bio, { practice_areas: [] }]
    )
  end

  def professional_params
    params.require(:professional).permit(:specialty, :license_number, :bio, :phone, practice_areas: [])
  end
end
