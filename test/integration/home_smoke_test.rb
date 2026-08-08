require "test_helper"

class HomeSmokeTest < ActionDispatch::IntegrationTest
  test "root renders the public home page with the engine navbar" do
    get root_path
    assert_response :success
    assert_select "header"            # engine base navbar
    assert_select ".card"             # home content card (engine component class)
    assert_select "h1", /Moms App/    # branded heading
  end

  test "login page renders the passwordless sign-in form" do
    get login_path
    assert_response :success
    assert_select "form"              # magic-link request form
  end

  test "admin-only pages require authentication" do
    get error_logs_path
    assert_redirected_to login_path
  end
end
