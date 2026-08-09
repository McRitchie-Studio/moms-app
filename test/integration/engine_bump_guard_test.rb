require "test_helper"

# [unit] This app must never run a studio-engine that needs a table it does not
# have.
#
# The exposure, precisely: below 1.0 a two-segment `~>` is a FLOOR, not a
# ceiling. `gem "studio-engine", "~> 0.29"` means `>= 0.29, < 1.0`, so it
# already admits 0.31.0 — the release that deleted the stateless :signed
# magic-link store and made the Studio::Link row store the only one. This app
# has no studio_links table and sets no magic_link_store, so the first sign-in
# after such a bump raises Studio::Link::MissingTable.
#
# Nothing else would catch it. This is a live public site, it is not in
# studio-engine's consumer-CI matrix, and a break would show up as a red CI on a
# branch whose CI is already red.
#
# The dependabot ignore added alongside this test is a HOLD and will be lifted
# by /tasks/adopt-short-links-moms. THIS test is the part that outlives it: it
# asserts the invariant itself, so it keeps working after the ignore is gone and
# fails if anyone bumps past 0.31 without installing the table — whether
# dependabot, a human, or a `bundle update` did it.
class EngineBumpGuardTest < ActiveSupport::TestCase
  # The release that made studio_links mandatory.
  ROW_STORE_FLOOR = Gem::Version.new("0.31.0")

  test "the engine in the lockfile does not outrun this app's schema" do
    version = locked_engine_version
    refute_nil version, "studio-engine must appear in Gemfile.lock"

    return if version < ROW_STORE_FLOOR

    assert ActiveRecord::Base.connection.table_exists?(:studio_links),
           "studio-engine #{version} serves magic links out of the studio_links table, and this " \
           "app has no such table — sign-in would raise Studio::Link::MissingTable. Install it " \
           "with `bin/rails studio_engine:install:migrations && bin/rails db:migrate` " \
           "(/tasks/adopt-short-links-moms), and lift the dependabot hold in the same PR."
  end

  # Guards the guard: if the lockfile parse ever stopped matching, the assertion
  # above would return early forever — green while checking nothing.
  test "the lockfile parse actually finds the engine" do
    assert_kind_of Gem::Version, locked_engine_version
  end

  # The hold itself. Asserted as DATA (the parsed ignore list), plus one text
  # check that it names the task that lifts it — an undocumented hold is how a
  # temporary pin becomes a permanent one nobody dares touch.
  test "dependabot holds studio-engine, and says which task lifts the hold" do
    raw    = dependabot_path.read
    config = YAML.safe_load(raw)

    bundler = config.fetch("updates").find { |u| u["package-ecosystem"] == "bundler" }
    refute_nil bundler, "the bundler ecosystem entry must still exist"

    ignored = (bundler["ignore"] || []).map { |i| i["dependency-name"] }
    assert_includes ignored, "studio-engine"

    assert_includes raw, "adopt-short-links-moms",
                    "the hold must name the task that lifts it, or it outlives its reason"
  end

  private

  def dependabot_path
    Rails.root.join(".github", "dependabot.yml")
  end

  def locked_engine_version
    line = Rails.root.join("Gemfile.lock").read[/^\s{4}studio-engine \(([\d.]+)\)/, 1]
    line && Gem::Version.new(line)
  end
end
