require "test_helper"

class ClinicIntegrationTest < ActiveSupport::TestCase
  test "ensure_catalog creates builtin providers once" do
    records = ClinicIntegration.ensure_catalog!

    assert_equal ClinicIntegration::BUILTIN_KINDS.size, records.size
    assert_equal ClinicIntegration::BUILTIN_KINDS.sort, ClinicIntegration.pluck(:kind).sort
    assert ClinicIntegration.find_by!(provider: "calendar").connected?
  end

  test "smtp connected when address is set" do
    ClinicIntegration.ensure_catalog!
    Setting.current.update!(smtp_address: "smtp.example.com")

    assert ClinicIntegration.find_by!(provider: "smtp").connected?
  end

  test "custom integrations get unique providers" do
    first = ClinicIntegration.create!(kind: "custom", name: "Financeiro", webhook_url: "https://example.com/a")
    second = ClinicIntegration.create!(kind: "custom", name: "Financeiro", webhook_url: "https://example.com/b")

    refute_equal first.provider, second.provider
    assert first.provider.start_with?("custom-")
  end
end
