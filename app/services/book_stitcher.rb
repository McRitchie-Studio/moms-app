require "open-uri"
require "tmpdir"

# Downloads a book's included chapter MP3s and concatenates them into a single
# MP3 (re-encoded to CBR so chapter seeking is exact), then attaches the result
# to the Book. Every failure leaves a durable, attributable record.
class BookStitcher
  class StitchError < StandardError; end

  def initialize(book)
    @book = book
  end

  def call
    chapters = @book.included_chapters
    raise StitchError, "no included chapters" if chapters.empty?

    Dir.mktmpdir("moms-stitch") do |dir|
      inputs = chapters.each_with_index.map do |chapter, i|
        path = File.join(dir, format("%02d.mp3", i))
        download(chapter.source_url, path)
        path
      end

      output = File.join(dir, "book.mp3")
      concat(inputs, output, dir)

      @book.audio.purge if @book.audio.attached? # replace any prior stitch cleanly
      @book.audio.attach(
        io: File.open(output),
        filename: "#{@book.slug}.mp3",
        content_type: "audio/mpeg"
      )
      @book.update!(
        audio_duration_seconds: chapters.sum { |c| c.duration_seconds.to_f }.round,
        status: "ready",
        error_message: nil
      )
    end
    @book
  rescue StandardError => e
    Rails.logger.error("[BookStitcher] #{@book.source_identifier} failed: #{e.class}: #{e.message}")
    @book.update(status: "failed", error_message: "#{e.class}: #{e.message}")
    raise
  end

  private

  def download(url, path)
    tries = 0
    begin
      tries += 1
      URI.parse(url).open("User-Agent" => Librivox::Client::USER_AGENT, read_timeout: 300) do |io|
        IO.copy_stream(io, path)
      end
      raise "empty file" unless File.size?(path)
    rescue StandardError => e
      retry if tries < 3
      raise StitchError, "download failed (#{tries}x) #{url}: #{e.class} #{e.message}"
    end
  end

  def concat(inputs, output, dir)
    list = File.join(dir, "inputs.txt")
    File.write(list, inputs.map { |p| "file '#{p}'" }.join("\n"))

    ok = system(
      "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
      "-f", "concat", "-safe", "0", "-i", list,
      "-c:a", "libmp3lame", "-b:a", "128k", output
    )
    raise StitchError, "ffmpeg concat failed" unless ok && File.size?(output).to_i.positive?
  end
end
