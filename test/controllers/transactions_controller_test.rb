require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "tx-#{SecureRandom.hex(4)}@example.com", password: "password", role: "admin")
    sign_in @admin
  end

  test "transactions redirects to invoices" do
    get transactions_path
    assert_redirected_to invoices_path
  end
end
