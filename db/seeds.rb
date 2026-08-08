# Idempotent seed: the admin user + the Sherlock Holmes demo audiobook.
admin = User.find_or_create_by!(email: "alex@mcritchie.studio") do |u|
  u.name = "Alex McRitchie"
  u.role = "admin"
end
puts "Seeded admin: #{admin.email}"

# Demo audiobook — The Adventures of Sherlock Holmes, public domain (LibriVox,
# read by Mark F. Smith), served by the Internet Archive. The stitched MP3 is
# ~648MB, far above GitHub's file limit, so media is NOT committed; this seed
# re-digests it from the public-domain source (needs network + ffmpeg on PATH).
# Idempotent: skips when the book is already stitched. Set SEED_CHAPTER_LIMIT=2
# for a faster, lighter demo (first two chapters only).
SHERLOCK_ID = "adventures_sherlockholmes_1007_librivox".freeze
limit = ENV["SEED_CHAPTER_LIMIT"].presence&.to_i
book = Book.find_by(source_identifier: SHERLOCK_ID)

if book&.ready? && book.audio.attached?
  puts "Sherlock demo already present (#{book.audio_duration_seconds}s, #{book.chapters.count} chapters)."
else
  begin
    scope = limit ? "first #{limit} chapter(s)" : "the whole book (~648MB, a few minutes)"
    puts "Digesting Sherlock Holmes demo — #{scope}…"
    book = BookImporter.new.import(SHERLOCK_ID, limit: limit)
    BookStitcher.new(book).call
    book.reload
    puts "Sherlock demo ready: #{book.audio_duration_seconds}s across #{book.chapters.count} chapters."
  rescue StandardError => e
    warn "[seed] Skipped Sherlock demo (#{e.class}: #{e.message})."
    warn "[seed] Re-run `bin/rails db:seed` with network access + ffmpeg to build it."
  end
end
