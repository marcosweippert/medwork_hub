class UsersController < ApplicationController
  before_action :require_admin
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
      redirect_to users_path, notice: "User created. A welcome email with a temporary password was sent to #{@user.email}."
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
      redirect_to users_path, notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def invite
    password = CreateUserAccount.temporary_password
    @user.update!(password: password, password_confirmation: password, must_change_password: true)
    ClinicMailer.welcome(@user, password).deliver_now
    redirect_to users_path, notice: "A new temporary password was emailed to #{@user.email}."
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: "You cannot delete your own account."
    else
      @user.destroy
      redirect_to users_path, notice: "User deleted."
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
