class ProfilesController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    attrs = profile_params
    if attrs[:password].blank?
      attrs.delete(:password)
      attrs.delete(:password_confirmation)
    end
    if @user.update(attrs)
      bypass_sign_in(@user)
      redirect_to profile_path, notice: t("profiles.updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
