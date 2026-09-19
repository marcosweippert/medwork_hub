class UsersController < ApplicationController
  before_action :require_clinic_staff
  before_action :require_admin, only: %i[destroy]
  before_action :set_user, only: %i[show edit update destroy invite]

  def index
    @users = User.order(:name, :email)
    @users = @users.where("name ILIKE :q OR email ILIKE :q", q: like_query) if params[:q].present?
    @users = paginate(@users, per: 20)
  end

  def show; end

  def new
    @user = User.new(role: "staff")
    @user.build_professional
  end

  def create
    result = CreateUserAccount.call(
      name: user_params[:name],
      email: user_params[:email],
      role: user_params[:role],
      professional: user_params[:professional_attributes]
    )
    @user = result.user
    if result.ok?
      redirect_to users_path, notice: t("users.created", email: @user.email)
    else
      @user.build_professional if @user.professional.nil?
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    attrs = user_params
    attrs.delete(:professional_attributes) unless @user.professional
    if @user.update(attrs.except(:password, :password_confirmation))
      redirect_to users_path, notice: t("users.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def invite
    password = CreateUserAccount.temporary_password
    @user.update!(password: password, password_confirmation: password, must_change_password: true)
    CreateUserAccount.deliver_welcome(@user, password)
    redirect_to users_path, notice: t("users.invited", email: @user.email)
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: t("users.cannot_delete_self")
    else
      @user.destroy
      redirect_to users_path, notice: t("users.deleted")
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :name, :email, :role,
      professional_attributes: [:id, :specialty, :license_number, :phone, :bio, { practice_areas: [] }]
    )
  end
end
