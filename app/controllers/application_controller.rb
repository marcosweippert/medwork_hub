class ApplicationController < ActionController::Base
  include Paginatable
  include Returnable
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_current_user
  before_action :set_clinic_name, if: :devise_controller?
  before_action :require_password_change, if: :user_signed_in?
  before_action :run_operational_jobs, unless: :devise_controller?
  helper_method :admin_user?, :professional_user?, :clinic_staff?, :current_professional, :signed_in_home_path

  layout :app_layout

  private

  def app_layout
    user_signed_in? ? "application" : "session"
  end

  def set_current_user
    Current.user = current_user
  end

  def set_clinic_name
    @clinic_name = Setting.order(:id).first&.clinic_name.presence || "MedWork Hub"
  end

  def run_operational_jobs
    Invoice.expire_overdue!
    ReminderDispatch.call unless Rails.env.test?
  end

  def admin_user?
    current_user&.admin?
  end

  def professional_user?
    current_user&.professional?
  end

  def clinic_staff?
    current_user&.clinic_staff?
  end

  def current_professional
    current_user&.professional
  end

  def signed_in_home_path
    professional_user? ? rooms_path : root_path
  end

  def after_sign_in_path_for(resource)
    return edit_password_change_path if resource.must_change_password?

    resource.professional? ? rooms_path : root_path
  end

  def require_admin
    return if admin_user?

    redirect_to signed_in_home_path, alert: "Only admins can access this area."
  end

  def require_clinic_staff
    return if clinic_staff?

    redirect_to signed_in_home_path, alert: "You do not have access to this area."
  end

  def accessible_rooms
    rooms = Room.order(:name)
    return rooms unless professional_user?

    Room.for_professional(current_professional).order(:name)
  end

  def scope_to_current_professional(relation)
    return relation unless professional_user?

    return relation.none if current_professional.blank?

    relation.where(professional_id: current_professional.id)
  end

  def require_password_change
    return if devise_controller?
    return unless current_user.must_change_password?
    return if controller_name == "password_changes"

    redirect_to edit_password_change_path, alert: "Create a new password to finish your first access."
  end
end
