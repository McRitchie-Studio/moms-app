require "test_helper"

class AuthenticatedHomeTest < ActionDispatch::IntegrationTest
  # Regression: a signed-in user renders the engine navbar
  # (components/_user_nav -> components/_avatar), which calls
  # User#avatar / #avatar_color / #avatar_initials. A minimal User model
  # without them raised NoMethodError and 500'd the authenticated home page.
  def sign_in(user)
    token = MagicLink.generate(email: user.email, return_to: nil)
    post magic_link_consume_path(token: token)
  end

  test "signed-in home page renders the engine avatar without error" do
    user = User.create!(name: "Ada Lovelace", email: "ada@example.com")
    sign_in(user)

    get root_path
    assert_response :success
    assert_select "header"                                 # engine navbar rendered
    assert_select "div.rounded-full.font-bold.text-white"  # avatar initials circle
  end
end
