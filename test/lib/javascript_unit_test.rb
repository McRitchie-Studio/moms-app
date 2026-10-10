require "test_helper"
require "open3"

# [unit] Runs the node:test files in test/javascript inside the Rails suite, so
# CI's `test` job runs them with no lane of its own.
class JavascriptUnitTest < ActiveSupport::TestCase
  test "the JavaScript unit tests pass" do
    node = ENV["PATH"].to_s.split(File::PATH_SEPARATOR).map { |dir| File.join(dir, "node") }.find { |path| File.executable?(path) }
    if node.nil?
      flunk "CI has no node on PATH, so no JavaScript unit test ran" if ENV["CI"]
      skip "node is not installed"
    end

    files = Dir[Rails.root.join("test/javascript/*.test.mjs")].sort
    assert_not_empty files

    output, status = Open3.capture2e(node, "--test", *files)

    assert status.success?, output
    assert_match(/^# pass [1-9]/, output, "node ran no test")
  end
end
