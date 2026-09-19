require "test_helper"

class Api::V1::StatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "api-ad-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    @key = ApiKey.new(name: "Mobile", user: @admin, enabled: true)
    @token = @key.assign_new_token
    @key.save!
  end

  test "returns clinic status with a bearer token" do
    get api_v1_status_path, headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["ok"]
    assert_equal "Mobile", body["key"]
  end

  test "rejects a missing or disabled key" do
    get api_v1_status_path
    assert_response :unauthorized

    @key.update!(enabled: false)
    get api_v1_status_path, headers: { "X-Api-Key" => @token }
    assert_response :unauthorized
  end
end
