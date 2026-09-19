require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  test "authenticates by digest and never stores the raw token" do
    key = ApiKey.new(name: "Zapier", enabled: true)
    raw = key.assign_new_token
    key.save!

    assert_not_equal raw, key.reload.token_digest
    assert_equal 64, key.token_digest.length
    assert_equal key, ApiKey.authenticate(raw)
    assert_nil ApiKey.authenticate("mwh_wrong")
    assert key.masked_token.start_with?("mwh_")
    refute_includes key.masked_token, raw[-8, 8]
  end
end
