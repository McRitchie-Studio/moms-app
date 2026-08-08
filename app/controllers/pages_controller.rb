class PagesController < ApplicationController
  # The root is a public dashboard: the photo slideshow + the audiobook library.
  skip_before_action :require_authentication

  def index
    @books = Book.order(created_at: :desc)
  end
end
