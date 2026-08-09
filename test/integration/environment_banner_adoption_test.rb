# frozen_string_literal: true

require "test_helper"

# [component] This app renders the ENGINE's environment banner and keeps no
# hand-rolled strip of its own (studio-engine >= 0.30).
#
# The banner's rules belong to the engine and are tested there. What only this
# repo can assert is the adoption seam: that the layout delegates, and that the
# copied yellow <div> is really gone.
class EnvironmentBannerAdoptionTest < ActionDispatch::IntegrationTest
  LAYOUT = Rails.root.join("app/views/layouts/application.html.erb")

  test "the layout renders the shared engine partial" do
    assert_includes LAYOUT.read, %(render "studio/banners/environment")
  end

  # The strip was copied from the engine's old NEW_APP_SETUP.md § 9. Its tells:
  # the hardcoded amber, and the host's own production conditional.
  test "no hand-rolled environment strip survives" do
    layout = LAYOUT.read

    assert_not_includes layout, "#eab308", "the copied yellow banner div should be gone"
    assert_not_includes layout, "unless Rails.env.production?",
                        "the partial self-gates; the host must not re-decide"
  end

  test "the engine supplies the banner contract this layout depends on" do
    %i[qa_environment? show_environment_banner? environment_banner_message local_inbox_reachable?].each do |method|
      assert Studio.respond_to?(method), "studio-engine >= 0.30 must define Studio.#{method}"
    end
  end

  test "a rendered page links the local inbox" do
    get root_path

    assert_response :success
    assert_select "a[href='/_studio/local_emails']", minimum: 1
    assert_includes response.body, "#{Rails.env.capitalize} Environment"
  end
end
