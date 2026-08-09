# frozen_string_literal: true

require "test_helper"

# [integration] Regression: this app had no engine outbox table, so
# Studio::Email.deliver fell through to a plain async deliver_later and every
# captured email vanished — /_studio/local_emails was always empty, with no
# error anywhere to say why.
#
# The table is the fix; this asserts the behavior the table exists for, not just
# the schema.
class LocalEmailCaptureTest < ActionDispatch::IntegrationTest
  test "the engine outbox is installed" do
    assert Studio::EmailDelivery.available?, "studio_email_deliveries table must exist"
    assert_includes Studio::EmailDelivery.column_names, "email_key"
  end

  test "a magic link request records an outbox delivery row" do
    assert_difference "Studio::EmailDelivery.count", 1 do
      post magic_link_request_path, params: { email: "capture@example.com" }
    end

    delivery = Studio::EmailDelivery.recent.first
    assert_equal "UserMailer#magic_link", delivery.email_key
    assert_equal "capture@example.com", delivery.to
  end
end
