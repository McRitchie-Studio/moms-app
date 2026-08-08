# Fetches a book's metadata (fast: JSON + one small cover image), upserts the
# Book + its Chapters, and flags the first `limit` chapters for the stitch.
# The heavy audio download/concatenation is BookStitcher's job.
class BookImporter
  def initialize(client: Librivox::Client.build)
    @client = client
  end

  def import(identifier, limit: 2)
    data = @client.fetch_book(identifier)

    book = Book.find_or_initialize_by(source_identifier: identifier)
    book.assign_attributes(
      title: data.title,
      author: data.author,
      narrator: data.narrator,
      description: data.description,
      source: "librivox",
      source_url: data.source_url,
      full_duration_seconds: data.full_duration_seconds,
      status: "digesting",
      error_message: nil
    )
    book.save!

    data.chapters.each do |cd|
      chapter = book.chapters.find_or_initialize_by(position: cd.position)
      chapter.update!(
        title: cd.title,
        source_url: cd.url,
        duration_seconds: cd.duration_seconds,
        size_bytes: cd.size_bytes,
        included: limit.nil? || cd.position <= limit
      )
    end
    book.chapters.where("position > ?", data.chapters.size).destroy_all

    attach_cover(book, data.cover_url)
    book
  end

  private

  def attach_cover(book, url)
    return if url.blank? || book.cover.attached?

    io = URI.parse(url).open("User-Agent" => Librivox::Client::USER_AGENT, read_timeout: 30)
    book.cover.attach(io: io, filename: "#{book.slug}-cover.jpg", content_type: "image/jpeg")
  rescue StandardError => e
    Rails.logger.error("[BookImporter] cover download failed for #{book.source_identifier}: #{e.class}: #{e.message}")
  end
end
