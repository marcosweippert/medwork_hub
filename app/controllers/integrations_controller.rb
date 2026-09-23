class IntegrationsController < ApplicationController
  before_action :require_admin
  before_action :set_integration, only: %i[show edit update destroy connect disconnect test]

  def index
    @integrations = ClinicIntegration.ensure_catalog!
    @available_kinds = ClinicIntegration.available_kinds
  end

  def show; end

  def new
    kind = catalog_kind(params[:kind]) || "custom"
    @integration = ClinicIntegration.new(kind: kind, name: ClinicIntegration.default_name_for(kind))
  end

  def create
    @integration = ClinicIntegration.new(integration_params)
    @integration.enabled = true if @integration.webhook? && @integration.webhook_url.present?
    connect_if_ready(@integration)
    if @integration.save
      redirect_to integration_path(@integration), notice: t("integrations.created", name: @integration.display_name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @integration.assign_attributes(integration_params)
    connect_if_ready(@integration)
    if @integration.save
      redirect_to integration_path(@integration), notice: t("integrations.updated", name: @integration.display_name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @integration.deletable?
      redirect_to integrations_path, alert: t("integrations.required")
      return
    end

    name = @integration.display_name
    @integration.destroy!
    redirect_to integrations_path, notice: t("integrations.deleted", name: name)
  end

  def connect
    if @integration.form?
      redirect_to edit_integration_path(@integration)
      return
    end

    if @integration.settings_key.present?
      redirect_to settings_path(edit: @integration.settings_key)
      return
    end

    @integration.connect!
    redirect_to integrations_path, notice: t("integrations.connected", name: @integration.display_name)
  end

  def test
    kind = NotifyN8n.test(@integration)
    redirect_to integration_path(@integration), notice: t("integrations.n8n.test_ok_#{kind}")
  rescue NotifyN8n::RequestError, NotifyN8n::TimeoutError, SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    redirect_to integration_path(@integration), alert: t("integrations.n8n.test_failed", error: e.message)
  end

  def disconnect
    if @integration.required?
      redirect_to integrations_path, alert: t("integrations.required")
      return
    end

    if @integration.settings_key.present?
      redirect_to settings_path(edit: @integration.settings_key)
      return
    end

    @integration.disconnect!
    redirect_to integrations_path, notice: t("integrations.disconnected", name: @integration.display_name)
  end

  private

  def set_integration
    @integration = ClinicIntegration.find_by(provider: params[:provider])
    return if @integration

    redirect_to integrations_path, alert: t("integrations.unknown")
  end

  def integration_params
    permitted = params.require(:clinic_integration).permit(
      :name, :kind, :notes, :enabled, :webhook_url, :api_base_url, :api_token, :channel
    )
    permitted.delete(:kind) unless @integration.nil? || @integration.new_record?
    permitted
  end

  def catalog_kind(value)
    kind = value.to_s
    ClinicIntegration::CATALOG.key?(kind) ? kind : nil
  end

  def connect_if_ready(integration)
    integration.connected_at ||= Time.current if integration.enabled? || (integration.webhook? && integration.webhook_url.present? && integration.enabled?)
  end
end
