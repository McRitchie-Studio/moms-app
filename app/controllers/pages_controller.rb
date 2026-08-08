class PagesController < ApplicationController
  # The home page is public (the engine requires auth on every page by default).
  skip_before_action :require_authentication

  def index
  end
end
