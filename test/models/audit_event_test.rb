require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  test "summarizes field changes and redacts secrets" do
    event = AuditEvent.new(
      action: "user.updated",
      auditable_type: "User",
      auditable_id: 1,
      details: { "name" => %w[Ana Lia], "encrypted_password" => %w[old new] }.to_json
    )

    assert_match "Nome: Ana → Lia", event.changes_summary
    assert_includes event.changes_summary, "••••"
    refute_includes event.changes_summary, "new"
    assert_equal 2, event.change_count
  end
end
