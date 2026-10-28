require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  # The scaffold's from@example.com shipped once and Resend refused every
  # magic link (moms-app-mail-from-team). The sender must be a mcritchie.studio
  # address whatever Studio.mailer_from resolves to.
  test "the default sender is Studio.mailer_from" do
    with_mailer_from("Moms App <team@mcritchie.studio>") do
      assert_equal "Moms App <team@mcritchie.studio>", resolved_from
    end
  end

  test "an unset Studio.mailer_from falls back to the team address, never example.com" do
    with_mailer_from(nil) do
      assert_equal "Moms App <team@mcritchie.studio>", resolved_from
    end
  end

  test "the magic link mail is sent from mcritchie.studio" do
    with_mailer_from(nil) do
      mail = UserMailer.magic_link("mom@example.com", "tok123")
      assert_equal [ "team@mcritchie.studio" ], mail.from
      assert_no_match(/example\.com/, mail.from.join)
    end
  end

  private

  def resolved_from
    from = ApplicationMailer.default[:from]
    from.respond_to?(:call) ? ApplicationMailer.new.instance_exec(&from) : from
  end

  def with_mailer_from(value)
    original = Studio.mailer_from
    Studio.mailer_from = value
    yield
  ensure
    Studio.mailer_from = original
  end
end

class MomsAppSenderConfigTest < ActiveSupport::TestCase
  # The initializer once passed ses_from:, which the engine ignores, so the
  # sender fell to the engine's "McRitchie Studio" name.
  test "with no RESEND_MAILER_FROM the configured sender names Moms App" do
    assert_equal "Moms App <team@mcritchie.studio>", Studio.mailer_from_for_transport(env: {}, resend_from: "Moms App <team@mcritchie.studio>")
    assert_match(/\AMoms App <team@mcritchie\.studio>\z/, Studio.mailer_from) unless ENV["RESEND_MAILER_FROM"].present?
  end
end
