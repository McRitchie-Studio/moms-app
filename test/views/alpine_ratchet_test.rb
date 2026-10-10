require "test_helper"

# [static] The app's own code holds no Alpine but the body line the engine's
# layout contract requires: studio-engine's banner buttons and user nav bind
# through that scope, and `dev-mode` has no source but $store.devMode.
class AlpineRatchetTest < ActiveSupport::TestCase
  ROOTS = %w[app/views app/javascript app/helpers app/components].freeze

  DIRECTIVE = /
    \bx-(?:data|show|if|for|model|text|html|cloak|transition|ref|init|bind|on|effect|teleport)\b |
    (?:^|(?<=[\s"']))@[a-z][\w.-]*= |
    (?:^|(?<=[\s"'])):[a-z][\w-]*= |
    \bAlpine\b | alpine:init | \$(?:store|refs|dispatch|el|nextTick|watch)\b
  /x

  BODY = %(<body x-data class="bg-page text-body min-h-screen" :class="{ 'dev-mode': $store.devMode }">).freeze
  ALLOWED = { "app/views/layouts/application.html.erb" => [ BODY ] }.freeze

  test "only the engine's body contract uses Alpine" do
    assert_equal ALLOWED, alpine_lines
  end

  test "the scan sees each kind of directive" do
    [ %(<div x-data="{}">), %(<a @click="go()">), %(<p :class="on">), %(<b x-text="n">),
      "Alpine.store('modals')", "$store.modals.close()", "document.addEventListener('alpine:init', f)",
      # An attribute on a line of its own: the scan strips each line first.
      %(@click="open = !open"), %(:class="on && 'shadow-lg'") ].each do |line|
      assert_match DIRECTIVE, line
    end
    [ %(<div data-controller="carousel">), %(<a href="mailto:a@b.co">), %(<p class="sm:w-1/2">),
      %(style="scrollbar-width: none;"), %(data-action="scroll@window->scroll-shadow#update") ].each do |line|
      assert_no_match DIRECTIVE, line
    end
  end

  test "the carousel partial carries no script" do
    assert_no_match(/<script\b/i, File.read(Rails.root.join("app/views/slideshow/_carousel.html.erb")))
  end

  private

  def alpine_lines
    files = ROOTS.flat_map { |root| Dir[Rails.root.join(root, "**/*.{erb,js,rb}")] }
    assert_operator files.size, :>, 5, "the scan found no files"

    files.sort.each_with_object({}) do |path, found|
      lines = File.readlines(path).map(&:strip).grep(DIRECTIVE)
      found[relative(path)] = lines if lines.any?
    end
  end

  def relative(path)
    Pathname(path).relative_path_from(Rails.root).to_s
  end
end
