require "test_helper"

class SlideshowTest < ActionDispatch::IntegrationTest
  test "is public and renders all 19 family photos" do
    get slideshow_path
    assert_response :success
    assert_select "img[src*=?]", "karen/karen", count: SlideshowController::PHOTO_COUNT
    assert_select "[x-data*=?]", "karenSlideshow" # the carousel is wired
  end
end
