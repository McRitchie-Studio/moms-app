# Public signup is closed (app/controllers/concerns/closed_signup.rb). The gate is
# prepended onto the engine's own controllers, so a member still runs the
# engine's action untouched. to_prepare re-applies it after a dev code reload.
Rails.application.config.to_prepare do
  {
    MagicLinksController        => ClosedSignup::MagicLinkRequest,
    Studio::LinksController     => ClosedSignup::LinkClick,
    OmniauthCallbacksController => ClosedSignup::GoogleCallback,
    SessionsController          => ClosedSignup::SsoContinue
  }.each do |controller, gates|
    Array(gates).each { |gate| controller.prepend(gate) unless controller < gate }
  end

  # The sign-in email. The engine's default body promises "If you don't have an
  # account yet, we'll create one for you", which stopped being true here. The
  # text part is the host view app/views/user_mailer/magic_link.text.erb. An
  # operator's saved wording on /admin/emails still wins over this default.
  Studio::EmailCatalog.register(:magic_link, body: ClosedSignup::MAGIC_LINK_BODY)
end
