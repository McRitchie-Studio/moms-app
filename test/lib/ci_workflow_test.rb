require "test_helper"

# [unit] CI must run on every rung of the release ladder. bin/release prepare
# refuses to promote a rung CI never builds, and on 2026-09-28 it refused moms-app
# because this workflow ran on main only. This pins the triggers so that cannot
# come back quietly.
class CiWorkflowTest < ActiveSupport::TestCase
  test "CI runs on pushes to main, release and accepted" do
    workflow = YAML.safe_load_file(Rails.root.join(".github/workflows/ci.yml"))
    triggers = workflow.key?("on") ? workflow["on"] : workflow[true]

    assert_equal %w[accepted main release], Array(triggers.dig("push", "branches")).sort
  end
end
