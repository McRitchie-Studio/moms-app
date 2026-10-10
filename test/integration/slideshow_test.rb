require "test_helper"

class SlideshowTest < ActionDispatch::IntegrationTest
  test "is public and renders all 19 family photos" do
    get slideshow_path
    assert_response :success
    assert_select "img[src*=?]", "karen/karen", count: SlideshowController::PHOTO_COUNT
    assert_select "[data-controller=carousel][data-action='mouseenter->carousel#stop mouseleave->carousel#start']", 1 do
      assert_select "[data-carousel-target=track] img", count: SlideshowController::PHOTO_COUNT
      assert_select "button[data-action='carousel#prev']", text: "‹ Prev"
      assert_select "button[data-action='carousel#toggle'][data-carousel-target=toggle]", text: "Pause"
      assert_select "button[data-action='carousel#next']", text: "Next ›"
    end
  end
end
