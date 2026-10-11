require "test_helper"

class DocsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Docs Staff", email: "docs-#{SecureRandom.hex(4)}@example.com", password: "password", role: "staff")
    sign_in @user
  end

  test "index uses the application shell and Flowbite-style docs layout" do
    get docs_path
    assert_response :success
    assert_match "Documentação", response.body
    assert_match "Visão geral", response.body
    assert_match "Primeiros passos", response.body
    assert_match "Nesta página", response.body
    assert_select "aside.d-sidebar"
    assert_select ".docs-shell"
    assert_select "h1.docs-title", text: "Visão geral"
    assert_select "body.docs-body", count: 0
  end

  test "shows a markdown page with section anchors" do
    get doc_path("modulos")
    assert_response :success
    assert_match "Faturas", response.body
    assert_select "h1.docs-title", text: "Módulos"
    assert_select "h2[id]", minimum: 1
    assert_select ".docs-nav-link.is-active", text: "Módulos"
  end

  test "unknown page redirects" do
    get doc_path("nao-existe")
    assert_redirected_to docs_path
  end
end
