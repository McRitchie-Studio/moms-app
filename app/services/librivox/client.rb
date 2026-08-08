require "open-uri"
require "json"

module Librivox
  # Reads public-domain audiobook metadata + chapter MP3 URLs from the Internet
  # Archive (which hosts every LibriVox recording). Pure read: metadata JSON +
  # direct file URLs. Swap for MockClient in tests / offline via `.build`.
  class Client
    BookData = Data.define(
      :identifier, :title, :author, :narrator, :description,
      :cover_url, :full_duration_seconds, :source_url, :chapters
    )
    ChapterData = Data.define(:position, :title, :url, :duration_seconds, :size_bytes)

    class NotFound < StandardError; end

    ARCHIVE_META = "https://archive.org/metadata/%s".freeze
    DOWNLOAD     = "https://archive.org/download/%s/%s".freeze
    MP3_FORMATS  = ["128Kbps MP3", "VBR MP3", "64Kbps MP3"].freeze
    USER_AGENT   = "moms-app/0.1 (local audiobook library)".freeze

    def self.build
      if Rails.env.test? || ENV["LIBRIVOX_MOCK"] == "1"
        Librivox::MockClient.new
      else
        new
      end
    end

    def fetch_book(identifier)
      json  = get_json(format(ARCHIVE_META, identifier))
      md    = json["metadata"] || {}
      files = json["files"] || []
      raise NotFound, "no files for #{identifier}" if files.empty?

      fmt = MP3_FORMATS.find { |f| files.any? { |x| x["format"] == f } }
      raise NotFound, "no MP3 files for #{identifier}" unless fmt

      mp3s  = files.select { |f| f["format"] == fmt }.sort_by { |f| f["track"].to_i }
      cover = files.find { |f| f["format"].to_s.match?(/JPEG/i) && !f["name"].to_s.match?(/_thumb/i) }

      BookData.new(
        identifier: identifier,
        title: md["title"].to_s.strip,
        author: Array(md["creator"]).first,
        narrator: narrator_from(md["description"]),
        description: strip_tags(md["description"]),
        cover_url: cover && format(DOWNLOAD, identifier, escape_segment(cover["name"])),
        full_duration_seconds: hms_to_seconds(md["runtime"]),
        source_url: "https://archive.org/details/#{identifier}",
        chapters: mp3s.each_with_index.map do |f, i|
          ChapterData.new(
            position: i + 1,
            title: chapter_title(f["title"], i + 1),
            url: format(DOWNLOAD, identifier, escape_segment(f["name"])),
            duration_seconds: f["length"].to_f,
            size_bytes: f["size"].to_i
          )
        end
      )
    end

    private

    def get_json(url)
      body = URI.parse(url).open("User-Agent" => USER_AGENT, read_timeout: 30, &:read)
      JSON.parse(body)
    end

    def narrator_from(desc)
      strip_tags(desc)[/Read by ([^.\n]+)/, 1]&.strip
    end

    # LibriVox file titles arrive like "01 - A Scandal in Bohemia"; drop the
    # leading track number so chapter labels read cleanly.
    def chapter_title(raw, position)
      t = raw.to_s.strip.sub(/\A\d+\s*[-–.:]\s*/, "")
      t.presence || "Chapter #{position}"
    end

    def strip_tags(html)
      html.to_s.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
    end

    def hms_to_seconds(str)
      return nil if str.to_s.strip.empty?

      str.split(":").map(&:to_i).inject(0) { |acc, p| (acc * 60) + p }
    end

    def escape_segment(name)
      name.to_s.gsub(" ", "%20")
    end
  end
end
