require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @staff = User.create!(name: "Staff", email: "usr-st-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    @admin = User.create!(name: "Admin", email: "usr-ad-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
  end

  test "staff can open the new user form and create an account" do
    sign_in @staff
    get users_path
    assert_response :success
    assert_select "a[href=?]", new_user_path

    get new_user_path
    assert_response :success

    assert_difference "User.count", 1 do
      post users_path, params: { user: { name: "Novo Staff", email: "new-#{SecureRandom.hex(4)}@example.com", role: "staff" } }
    end
    assert_redirected_to users_path
  end

  test "professional cannot manage users" do
    pro = User.create!(name: "Pro", email: "usr-pro-#{SecureRandom.hex(4)}@example.com", password: "password", role: "professional")
    sign_in pro
    get users_path
    assert_redirected_to rooms_path
  end
end
