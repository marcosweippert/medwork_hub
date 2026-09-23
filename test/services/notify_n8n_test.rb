require "test_helper"

class NotifyN8nTest < ActiveSupport::TestCase
  test "skips when n8n is not connected" do
    ClinicIntegration.ensure_catalog!
    assert_nil NotifyN8n.event("booking.created", { id: 1 })
  end
end
