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

  # Passwordless: email proof comes from MagicLink.consume; Google proof comes
  # from OmniAuth. No throwaway passwords are assigned.
  def self.from_omniauth(auth)
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    user = find_by(email: auth.info.email)
    if user
      user.update!(provider: auth.provider, uid: auth.uid)
      return user
    end

    create!(
      email: auth.info.email,
      name: auth.info.name,
      provider: auth.provider,
      uid: auth.uid
    )
  rescue ActiveRecord::RecordNotUnique
    find_by(email: auth.info.email) || find_by(provider: auth.provider, uid: auth.uid)
  end
end
