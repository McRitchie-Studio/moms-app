class Book < ApplicationRecord
  include Sluggable

  STATUSES = %w[pending digesting ready failed].freeze

  has_many :chapters, -> { order(:position) }, dependent: :destroy
  has_one_attached :cover
  has_one_attached :audio

  validates :status, inclusion: { in: STATUSES }

  def name_slug
    title.present? ? title.parameterize : "book-#{source_identifier.presence || SecureRandom.hex(4)}"
  end

  def ready?
    status == "ready"
  end

  def digesting?
    %w[pending digesting].include?(status)
  end

  def failed?
    status == "failed"
  end

  def included_chapters
    chapters.select(&:included)
  end

  # Cumulative start offset (seconds) of each included chapter within the
  # stitched file — powers the player's chapter seek buttons.
  def chapter_offsets
    offset = 0.0
    included_chapters.map do |ch|
      start = offset
      offset += ch.duration_seconds.to_f
      [ch, start.round]
    end
  end
end
