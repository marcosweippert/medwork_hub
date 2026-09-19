class ApiKeysController < ApplicationController
  before_action :require_admin
  before_action :set_api_key, only: %i[edit update destroy regenerate toggle]

  def index
    @api_keys = paginate(ApiKey.newest.includes(:user), per: 20)
    @api_key = ApiKey.new(renewal_on: 1.year.from_now.to_date)
  end

  def create
    @api_key = ApiKey.new(api_key_params.merge(user: current_user, enabled: true))
    @api_key.assign_new_token
    if @api_key.save
      flash[:notice] = t("api_keys.created")
      flash[:api_token] = @api_key.raw_token
      flash[:api_key_name] = @api_key.name
      redirect_to api_keys_path
    else
      @api_keys = paginate(ApiKey.newest.includes(:user), per: 20)
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @api_key.update(api_key_params)
      redirect_to api_keys_path, notice: t("api_keys.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle
    @api_key.update!(enabled: !@api_key.enabled?)
    redirect_to api_keys_path, notice: @api_key.enabled? ? t("api_keys.enabled") : t("api_keys.disabled")
  end

  def regenerate
    @api_key.assign_new_token
    @api_key.save!
    flash[:notice] = t("api_keys.regenerated")
    flash[:api_token] = @api_key.raw_token
    flash[:api_key_name] = @api_key.name
    redirect_to api_keys_path
  end

  def destroy
    @api_key.destroy
    redirect_to api_keys_path, notice: t("api_keys.deleted")
  end

  def bulk
    keys = ApiKey.where(id: Array(params[:ids]))
    case params[:bulk_action]
    when "activate"
      keys.update_all(enabled: true, updated_at: Time.current)
      notice = t("api_keys.bulk_activated")
    when "deactivate"
      keys.update_all(enabled: false, updated_at: Time.current)
      notice = t("api_keys.bulk_deactivated")
    when "delete"
      keys.destroy_all
      notice = t("api_keys.bulk_deleted")
    else
      notice = t("api_keys.updated")
    end
    redirect_to api_keys_path, notice: notice
  end

  private

  def set_api_key
    @api_key = ApiKey.find(params[:id])
  end

  def api_key_params
    params.require(:api_key).permit(:name, :renewal_on)
  end
end
