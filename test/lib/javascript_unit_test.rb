require "test_helper"
require "open3"

# [unit] Runs the node:test files in test/javascript inside the Rails suite, so
# CI's `system` lane runs them with no lane of its own. They import app modules
# by their importmap names through studio-engine's shared hook
# (test/javascript/support/register.mjs), reached through the
# node_modules/.studio-engine link this test makes.
#
# Node is the major .tool-versions pins: under mise (a laptop) the run goes
# through `mise exec`, which reads it; in CI it is the runner's node on PATH,
# and a different major fails here rather than testing the wrong Node.
class JavascriptUnitTest < ActiveSupport::TestCase
  def self.on_path(name)
    ENV["PATH"].to_s.split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }.find { |path| File.executable?(path) }
  end

  def pinned_major
    Rails.root.join(".tool-versions").read.lines.map(&:split).find { |tool, *| %w[nodejs node].include?(tool) }&.last
  end

  def node_command
    if (mise = self.class.on_path("mise"))
      [ mise, "exec", "node@#{pinned_major}", "--", "node" ]
    elsif (node = self.class.on_path("node"))
      [ node ]
    end
  end

  test "the JavaScript unit tests pass on the pinned Node" do
    node = node_command
    if node.nil?
      flunk "CI has no node on PATH, so no JavaScript unit test ran" if ENV["CI"]
      skip "node is not installed"
    end

    running, = Open3.capture2(*node, "-p", 'process.versions.node.split(".")[0]')
    assert_equal pinned_major, running.strip, "node is #{running.strip}, but .tool-versions pins nodejs #{pinned_major}"

    Studio::NodeTooling.link!(Rails.root)
    files = Dir[Rails.root.join("test/javascript/*.test.mjs")].sort
    assert_not_empty files

    output, status = Open3.capture2e(*node, "--import", "./test/javascript/support/register.mjs", "--test", *files,
                                     chdir: Rails.root.to_s)

    assert status.success?, output
    assert_match(/^# pass [1-9]/, output, "node ran no test")
    assert_match(/^# fail 0$/, output)
  end
end
