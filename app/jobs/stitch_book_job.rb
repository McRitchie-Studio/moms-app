class StitchBookJob < ApplicationJob
  queue_as :default

  def perform(book)
    BookStitcher.new(book).call
  rescue StandardError => e
    # BookStitcher already logged + marked the book failed; swallow so the job
    # doesn't retry-loop a permanently-bad source.
    Rails.logger.error("[StitchBookJob] book=#{book.id} #{e.class}: #{e.message}")
  end
end
