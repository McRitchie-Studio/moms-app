class ApplicationMailer < ActionMailer::Base
  # The sender configured in config/initializers/studio.rb (Studio.mailer_from,
  # resolved per transport). This class shadows the engine's ApplicationMailer,
  # so every mailer inherits it, the engine's UserMailer (the magic link)
  # included. Every app sends from team@mcritchie.studio; a client's own
  # sending domain is a tier upgrade. The scaffold's "from@example.com" sat
  # here, which Resend refuses.
  default from: -> { Studio.mailer_from.presence || "Moms App <team@mcritchie.studio>" }
  layout "mailer"
end
