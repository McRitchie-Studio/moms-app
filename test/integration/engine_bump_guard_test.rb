require "test_helper"

# This app must never run a studio-engine that needs a table it does not have.
#
# The exposure, precisely: below 1.0 a two-segment `~>` is a FLOOR, not a
# ceiling. `gem "studio-engine", "~> 0.31"` means `>= 0.31, < 1.0`. Engine 0.31
# deleted the stateless :signed magic-link store and made the Studio::Link row
# store the only one, so from that release on, magic-link sign-in REQUIRES the
# studio_links table. Without it the first sign-in raises
# Studio::Link::MissingTable.
#
# THIS IS NOW THE WHOLE GUARD. It shipped alongside a dependabot ignore that
# froze studio-engine while the table was missing; that hold has been LIFTED in
# the same change that installed the table, exactly as its comment promised. The
# freeze was temporary by design — this assertion is not, and it is what keeps
# the app safe now that bumps flow again. It fails whether dependabot, a human,
# or a bare `bundle update` crosses the line.
#
# Nothing else would catch it: this is a live public site, it is not in
# studio-engine's consumer-CI matrix, and the failure would surface only when a
# real person tried to sign in.
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
           "with `bin/rails studio_engine:install:migrations && bin/rails db:migrate` (install " \
           "ALL of them; do not hand-copy, which collides on `class CreateStudioLinks`)."
  end

  # Guards the guard, twice over. The assertion above early-returns below the
  # floor, so a lockfile that stopped parsing — or an app that drifted back below
  # 0.31 — would leave it passing while checking nothing.
  test "the guard is actually exercised, not early-returning" do
    version = locked_engine_version

    assert_kind_of Gem::Version, version
    assert_operator version, :>=, ROW_STORE_FLOOR,
                    "this app is on the row-store line, so the assertion above must be doing real work"
  end

  # The reason the hold could be lifted. Asserted directly, so "the table is
  # there" is a checked fact rather than an assumption inherited from a migration
  # that ran once on someone's laptop.
  test "the studio_links table is present and usable" do
    assert ActiveRecord::Base.connection.table_exists?(:studio_links)

    link = Studio::Link.create_magic_link(email: "guard@example.com")
    assert_match(/\A[A-Za-z0-9_-]{16}\z/, link.token,
                 "a house magic-link token is 16 URL-safe characters")
    assert link.live?
  end

  private

  # The RESOLVED engine version, read from the lockfile rather than the Gemfile
  # constraint — the constraint is a floor and says nothing about what is
  # actually installed, which is the whole trap this guard exists for.
  def locked_engine_version
    line = Rails.root.join("Gemfile.lock").read[/^\s{4}studio-engine \(([\d.]+)\)/, 1]
    line && Gem::Version.new(line)
  end
end
