require "test_helper"

class BillingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "bill-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    sign_in @admin
  end

  test "billing redirects to invoices" do
    get billing_path
    assert_redirected_to invoices_path
  end
end
