class User < ApplicationRecord
  include Sluggable

  has_one_attached :avatar

  AVATAR_COLORS = %w[#EF4444 #F97316 #EAB308 #22C55E #06B6D4 #3B82F6 #8B5CF6 #EC4899].freeze

  def name_slug
    name.present? ? name.parameterize : "user-#{id}"
  end

  def display_name
    name.presence || email&.split("@")&.first || "User"
  end

  def admin?
    role == "admin"
  end

  # Engine navbar avatar contract (studio-engine components/_avatar): an
  # attachable image, a deterministic fallback color, and initials.
  def avatar_initials
    (name.presence || email&.split("@")&.first || "?").first.upcase
  end

  def avatar_color
    key = name.presence || email || id.to_s
    AVATAR_COLORS[Digest::MD5.hexdigest(key).hex % AVATAR_COLORS.size]
  end

  # One spelling per address. The engine downcases what a visitor types before it
  # looks a member up, so a row the operator saved as "Mom@Example.com" would
  # never match. Normalizing here covers the console, the seed and every query.
  normalizes :email, with: ->(email) { email.strip.downcase }

  # --- Membership: public signup is closed (ClosedSignup) ---------------------

  # Is there an account for this address? The only question the signup gate asks.
  def self.member_email?(email)
    email = email.to_s.strip.downcase
    email.present? && exists?(email: email)
  end

  # Does this Google identity belong to an account, by its linked Google id or by
  # its address? Read-only; it decides only whether the callback is worth running.
  def self.google_member?(auth)
    return false if auth.blank?

    (auth.uid.present? && exists?(provider: auth.provider, uid: auth.uid)) ||
      member_email?(auth.info&.email)
  end

  # Google sign-in for an EXISTING member. Never creates: an unknown Google
  # account gets nil, which the engine's callback refuses.
  #
  # `email_verified:` is the engine's contract (studio-engine docs/USER_CONTRACT.md):
  # the callback passes Google's own verdict after re-validating the id_token. An
  # account is linked by address only on a verified one, since an unverified
  # address proves nothing about who holds the mailbox.
  def self.from_omniauth(auth, email_verified: false)
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user
    return nil unless email_verified

    user = find_by(email: auth.info.email)
    return nil unless user

    user.update!(provider: auth.provider, uid: auth.uid)
    user
  end
end
