require "test_helper"

class ApiKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "key-ad-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    sign_in @admin
  end

  test "admin generates a key and sees the raw token once" do
    assert_difference "ApiKey.count", 1 do
      post api_keys_path, params: { api_key: { name: "Zapier", renewal_on: 1.year.from_now.to_date } }
    end
    assert_redirected_to api_keys_path
    follow_redirect!
    assert_match "mwh_", response.body
    assert_match "Copie agora", response.body

    get api_keys_path
    assert_response :success
    assert_no_match ApiKey.last.token_digest, response.body
    assert_match "mwh_", response.body
  end

  test "toggles bulk deactivates and deletes" do
    key = ApiKey.new(name: "App", user: @admin, enabled: true, renewal_on: Date.current)
    key.assign_new_token
    key.save!

    patch toggle_api_key_path(key)
    refute key.reload.enabled?

    patch bulk_api_keys_path, params: { ids: [key.id], bulk_action: "activate" }
    assert key.reload.enabled?

    patch bulk_api_keys_path, params: { ids: [key.id], bulk_action: "delete" }
    assert_nil ApiKey.find_by(id: key.id)
  end

  test "staff cannot manage api keys" do
    staff = User.create!(name: "Staff", email: "key-st-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    sign_in staff
    get api_keys_path
    assert_redirected_to root_path
  end
end
