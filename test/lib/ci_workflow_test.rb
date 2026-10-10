require "test_helper"

# [unit] CI must run on every rung of the release ladder (bin/release prepare
# refuses to promote a rung CI never builds), and it must run this app's whole
# suite through the hub's reusable workflow. This pins the triggers, the call
# and every input it passes.
class CiWorkflowTest < ActiveSupport::TestCase
  SUITE = "McRitchie-Studio/mcritchie-studio/.github/workflows/reusable-ci.yml@main".freeze

  # `system` stays at the hub's default (on); each other lane is one this app
  # does not have. Postgres is production's major (18, heroku pg:info).
  INPUTS = {
    "javascript" => false,
    "island-animator" => false,
    "playwright" => false,
    "rails-shards" => false,
    "await-gem-propagation" => false,
    "postgres-image" => "public.ecr.aws/docker/library/postgres:18",
    "gem-audit-command" => "bin/bundler-audit",
    "importmap-audit-command" => "bin/importmap audit",
    "system-packages" => "libpq-dev libvips ffmpeg",
    "system-command" => "bin/rails db:test:prepare test test:system"
  }.freeze

  def workflow
    @workflow ||= YAML.safe_load_file(Rails.root.join(".github/workflows/ci.yml"))
  end

  def triggers
    workflow.key?("on") ? workflow["on"] : workflow[true]
  end

  def call
    workflow.dig("jobs", "ci")
  end

  test "CI runs on pull requests and on pushes to main, release and accepted" do
    assert triggers.key?("pull_request")
    assert_equal %w[accepted main release], Array(triggers.dig("push", "branches")).sort
  end

  test "no concurrency block can cancel a rung's run" do
    refute workflow.key?("concurrency"), "a cancelled run reads as RED to the release tooling"
  end

  test "the one job calls the hub's reusable suite and nothing else" do
    assert_equal [ "ci" ], workflow["jobs"].keys
    assert_equal SUITE, call["uses"]
    assert_equal %w[uses with], call.keys.sort,
                 "an `if:` skips every lane and still reads green; the suite takes no secrets"
  end

  test "the call passes exactly this app's inputs" do
    assert_equal INPUTS, call["with"]
  end

  test "the call runs the unit, integration and system suites, and there are system tests" do
    argv = call.dig("with", "system-command").split

    assert_equal "db:test:prepare", argv[1], "a leading rake task routes both tiers through rake"
    assert_includes argv, "test"
    assert_includes argv, "test:system"
    refute_empty Dir[Rails.root.join("test/system/**/*_test.rb")], "a system lane over an empty directory tests nothing"
  end

  test "the system lane installs ffmpeg, which BookStitcher shells out to" do
    assert_includes call.dig("with", "system-packages").split, "ffmpeg"
  end

  test "Dependabot opens every PR into accepted" do
    updates = YAML.safe_load_file(Rails.root.join(".github/dependabot.yml"))["updates"]

    assert_equal %w[bundler github-actions], updates.map { |u| u["package-ecosystem"] }.sort
    updates.each do |update|
      assert_equal "accepted", update["target-branch"],
                   "#{update['package-ecosystem']} PRs would target the default branch, skipping review's rung"
    end
  end

  test "the scripts the lanes run from this tree exist" do
    %w[.github/scripts/apt-retry bin/brakeman bin/bundler-audit bin/importmap bin/rubocop].each do |path|
      assert File.executable?(Rails.root.join(path)), "#{path} is missing or not executable"
    end
  end
end
