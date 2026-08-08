require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "satisfies the studio-engine avatar contract" do
    user = User.new(name: "Ada Lovelace", email: "ada@example.com")
    assert_not user.avatar.attached?
    assert_match(/\A#[0-9A-F]{6}\z/i, user.avatar_color)
    assert_equal "A", user.avatar_initials
  end

  test "avatar_initials falls back to email, then a placeholder" do
    assert_equal "B", User.new(email: "bob@example.com").avatar_initials
    assert_equal "?", User.new.avatar_initials
  end
end
