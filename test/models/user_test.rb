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

  # ---- [unit] Membership: public signup is closed ---------------------------

  def google_auth(email:, uid:)
    OmniAuth::AuthHash.new(provider: "google_oauth2", uid: uid, info: { email: email, name: "Google User" })
  end

  test "an address is saved in one spelling, whoever typed it" do
    user = User.create!(email: "  Mom@Example.COM ", name: "Mom")

    assert_equal "mom@example.com", user.email
    assert_equal user, User.find_by(email: "MOM@example.com"), "and a lookup is normalized the same way"
  end

  test "member_email? knows a member and nobody else" do
    User.create!(email: "mom@example.com", name: "Mom")

    assert User.member_email?("mom@example.com")
    assert User.member_email?("  Mom@Example.COM "), "however it is typed"
    refute User.member_email?("stranger@example.com")
    refute User.member_email?("mom@example.com.evil.test")
    refute User.member_email?("")
    refute User.member_email?(nil)
  end

  test "a blank address never matches an account that has no address" do
    User.create!(name: "No Email")

    refute User.member_email?(nil)
    refute User.member_email?("   ")
  end

  test "google_member? matches by linked Google id or by address" do
    User.create!(email: "mom@example.com", name: "Mom")
    User.create!(email: "dad@example.com", name: "Dad", provider: "google_oauth2", uid: "g-dad")

    assert User.google_member?(google_auth(email: "mom@example.com", uid: "g-new"))
    assert User.google_member?(google_auth(email: "other@example.com", uid: "g-dad"))
    refute User.google_member?(google_auth(email: "stranger@example.com", uid: "g-stranger"))
    refute User.google_member?(nil)
  end

  test "from_omniauth never creates an account for an unknown Google identity" do
    assert_no_difference -> { User.count } do
      assert_nil User.from_omniauth(google_auth(email: "stranger@example.com", uid: "g-1"), email_verified: true)
    end
  end

  test "from_omniauth links a member by a verified address" do
    mom = User.create!(email: "mom@example.com", name: "Mom")

    assert_equal mom, User.from_omniauth(google_auth(email: "mom@example.com", uid: "g-mom"), email_verified: true)
    assert_equal %w[google_oauth2 g-mom], mom.reload.values_at(:provider, :uid)
  end

  test "from_omniauth does not link a member by an unverified address" do
    mom = User.create!(email: "mom@example.com", name: "Mom")

    assert_nil User.from_omniauth(google_auth(email: "mom@example.com", uid: "g-imposter"), email_verified: false)
    assert_nil mom.reload.uid
  end

  test "from_omniauth finds an already linked member without the address" do
    dad = User.create!(email: "dad@example.com", name: "Dad", provider: "google_oauth2", uid: "g-dad")

    assert_equal dad, User.from_omniauth(google_auth(email: "moved@example.com", uid: "g-dad"))
  end

  # The engine calls from_omniauth(auth, email_verified:). Before this was fixed
  # the method took one argument, so every Google sign-in raised ArgumentError.
  test "from_omniauth takes the engine's email_verified keyword" do
    assert_includes User.method(:from_omniauth).parameters, [ :key, :email_verified ]
  end
end
