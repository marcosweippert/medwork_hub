require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "staff signs in and opens the dashboard" do
    email = "sys-#{SecureRandom.hex(4)}@example.com"
    User.create!(name: "Staff Sistema", email: email, password: "password", role: "staff")

    visit new_user_session_path
    fill_in "E-mail", with: email
    fill_in "Senha", with: "password"
    click_button "Entrar"

    assert_text "Staff"
    assert_current_path root_path
  end
end
