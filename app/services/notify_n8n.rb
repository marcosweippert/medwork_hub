require "json"
require "net/http"
require "uri"

class NotifyN8n
  TimeoutError = Class.new(StandardError)
  RequestError = Class.new(StandardError)

  def self.event(name, payload = {})
    new.event(name, payload)
  end

  def self.test(integration)
    new.test(integration)
  end

  def event(name, payload = {})
    targets = ClinicIntegration.webhook_targets
    return if targets.empty?

    body = {
      event: name,
      clinic: Setting.current.clinic_name,
      occurred_at: Time.current.iso8601,
      data: payload
    }
    targets.each do |integration|
      post_json(integration.webhook_url, body)
    rescue StandardError => e
      Rails.logger.warn("webhook #{integration.provider} failed: #{e.class}: #{e.message}")
    end
  end

  def test(integration)
    if integration.webhook_url.present?
      post_json(integration.webhook_url, {
        event: "n8n.test",
        clinic: Setting.current.clinic_name,
        occurred_at: Time.current.iso8601,
        data: { ok: true }
      })
      return :webhook
    end

    if integration.api_token.present? && integration.api_base_url.present?
      ping_api(integration)
      return :api
    end

    raise RequestError, I18n.t("integrations.n8n.missing_config")
  end

  private

  def ping_api(integration)
    uri = URI.parse("#{integration.api_base_url}/api/v1/workflows?limit=1")
    request = Net::HTTP::Get.new(uri)
    request["X-N8N-API-KEY"] = integration.api_token
    request["Accept"] = "application/json"
    response = http(uri).request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise RequestError, "n8n API #{response.code}"
    end
  end

  def post_json(url, body)
    uri = URI.parse(url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request.body = JSON.generate(body)
    response = http(uri).request(request)
    unless response.is_a?(Net::HTTPSuccess) || response.code.to_i == 204
      raise RequestError, "n8n webhook #{response.code}"
    end
  end

  def http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 8
    http
  end
end
