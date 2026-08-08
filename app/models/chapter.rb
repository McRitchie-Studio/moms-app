class Chapter < ApplicationRecord
  belongs_to :book

  validates :position, presence: true, uniqueness: { scope: :book_id }
end
