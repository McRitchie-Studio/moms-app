require "test_helper"

class HomeSmokeTest < ActionDispatch::IntegrationTest
  test "root shows the slideshow first, then the library" do
    get root_path
    assert_response :success
    assert_select "header"                            # engine base navbar
    assert_select "[x-data*=?]", "karenSlideshow"     # slideshow carousel
    assert_select "img[src*=?]", "karen/karen", minimum: 1
    assert_select "h2", text: /Library/               # library section below
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
