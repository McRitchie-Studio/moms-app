class BooksController < ApplicationController
  # Public family site — no sign-in required to browse or listen.
  skip_before_action :require_authentication

  def index
    @books = Book.order(created_at: :desc)
  end

  def show
    @book = Book.find_by!(slug: params[:id])
  end

  def new
    @book = Book.new
  end

  # Import metadata now (fast), then stitch the audio in the background.
  def create
    identifier = params[:identifier].to_s.strip
    raw_limit = params[:chapter_limit].to_s.strip
    limit = raw_limit.empty? ? nil : raw_limit.to_i
    limit = nil if limit && limit <= 0 # blank / 0 = the whole book

    if identifier.blank?
      redirect_to(new_book_path, alert: "Enter a LibriVox / Internet Archive identifier.") and return
    end

    book = BookImporter.new.import(identifier, limit: limit)
    StitchBookJob.perform_later(book)
    scope = limit ? "the first #{limit} chapter(s)" : "the whole book"
    redirect_to book_path(book.slug), notice: "Digesting “#{book.title}” — stitching #{scope} now."
  rescue Librivox::Client::NotFound => e
    redirect_to new_book_path, alert: "Couldn't find that book: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("[BooksController#create] #{e.class}: #{e.message}")
    redirect_to new_book_path, alert: "Something went wrong importing that book."
  end
end
