require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(name: "Staff", email: "rep-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    sign_in user
  end

  test "index lists report catalog" do
    get reports_path
    assert_response :success
    assert_match "Occupancy", response.body
  end
end
