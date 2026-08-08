require "test_helper"
require "fileutils"

class BookStitcherTest < ActiveSupport::TestCase
  # Swaps the network download for local fixture copies so the ffmpeg concat
  # runs for real without hitting archive.org.
  class LocalStitcher < BookStitcher
    def initialize(book, clips)
      super(book)
      @clips = clips
    end

    private

    def download(url, path)
      FileUtils.cp(@clips.fetch(url), path)
    end
  end

  setup do
    @dir = Dir.mktmpdir
    @clip1 = File.join(@dir, "a.mp3"); make_clip(@clip1)
    @clip2 = File.join(@dir, "b.mp3"); make_clip(@clip2)

    @book = Book.create!(title: "Test Book", source_identifier: "test_book", status: "digesting")
    @book.chapters.create!(position: 1, title: "One",   duration_seconds: 1.0, included: true,  source_url: "https://x/1.mp3")
    @book.chapters.create!(position: 2, title: "Two",   duration_seconds: 1.0, included: true,  source_url: "https://x/2.mp3")
    @book.chapters.create!(position: 3, title: "Three", duration_seconds: 1.0, included: false, source_url: "https://x/3.mp3")
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "downloads only the included chapters and stitches one MP3" do
    clips = { "https://x/1.mp3" => @clip1, "https://x/2.mp3" => @clip2 }
    LocalStitcher.new(@book, clips).call

    @book.reload
    assert_equal "ready", @book.status
    assert @book.audio.attached?
    assert_equal 2, @book.audio_duration_seconds # 1s + 1s
    assert_operator @book.audio.blob.byte_size, :>, 0
  end

  private

  # A 1-second silent MP3 so ffmpeg concat runs for real without a fixture file.
  def make_clip(path)
    ok = system(
      "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
      "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "1",
      "-c:a", "libmp3lame", "-b:a", "64k", path
    )
    raise "ffmpeg fixture generation failed" unless ok
  end
end
