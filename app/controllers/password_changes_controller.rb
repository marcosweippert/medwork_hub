class PasswordChangesController < ApplicationController
  skip_before_action :require_password_change
  before_action :set_clinic_name
  layout "session"

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(password_params.merge(must_change_password: false))
      bypass_sign_in(@user)
      redirect_to (current_user.professional? ? rooms_path : root_path), notice: "Password updated. Welcome to MedWork Hub."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
