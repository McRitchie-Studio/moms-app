require "test_helper"

class SlideshowTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    token = MagicLink.generate(email: user.email, return_to: nil)
    post magic_link_consume_path(token: token)
  end

  test "renders all 19 family photos in the slideshow" do
    sign_in(User.create!(name: "Mom", email: "mom@example.com"))
    get slideshow_path
    assert_response :success
    assert_select "img[src*=?]", "karen/karen", count: SlideshowController::PHOTO_COUNT
    assert_select "[x-data*=?]", "karenSlideshow" # the carousel is wired
  end

  test "requires sign-in" do
    get slideshow_path
    assert_redirected_to login_path
  end
end
