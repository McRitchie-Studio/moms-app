# Public signup is closed (app/controllers/concerns/closed_signup.rb). The gate is
# prepended onto the engine's own controllers, so a member still runs the
# engine's action untouched. to_prepare re-applies it after a dev code reload.
Rails.application.config.to_prepare do
  {
    MagicLinksController        => ClosedSignup::MagicLinkRequest,
    Studio::LinksController     => ClosedSignup::LinkClick,
    OmniauthCallbacksController => ClosedSignup::GoogleCallback,
    SessionsController          => ClosedSignup::SsoContinue
  }.each do |controller, gate|
    controller.prepend(gate) unless controller < gate
  end
end
