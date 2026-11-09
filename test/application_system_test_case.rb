require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  SCREEN_SIZE = [ 1400, 1400 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: SCREEN_SIZE

  # One browser serves every test, so a test that resizes the window would leave
  # the next test at its size (a 500px home test made a later 1400px assertion
  # read 500 under CI's random order). Every test starts at the default size.
  setup { page.current_window.resize_to(*SCREEN_SIZE) }
end
