require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Ana Staff", email: "prof-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    sign_in @user
  end

  test "user updates own profile" do
    get profile_path
    assert_response :success

    patch profile_path, params: { user: { name: "Ana Atualizada", email: @user.email, password: "", password_confirmation: "" } }
    assert_redirected_to profile_path
    assert_equal "Ana Atualizada", @user.reload.name
  end
end
