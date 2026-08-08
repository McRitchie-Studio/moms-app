class SlideshowController < ApplicationController
  # Karen's family photos, bundled in app/assets/images/karen/ (absorbed from the
  # old karen_mcritchie app). Static for now; a DB-backed gallery can come later.
  PHOTO_COUNT = 19

  def index
    @photos = (1..PHOTO_COUNT).map { |i| "karen/karen#{i}.jpg" }
  end
end
