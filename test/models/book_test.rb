require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "slug derives from the title" do
    book = Book.create!(title: "The Adventures of Sherlock Holmes", source_identifier: "x", status: "pending")
    assert_equal "the-adventures-of-sherlock-holmes", book.slug
  end

  test "chapter_offsets are cumulative over the included chapters only" do
    book = Book.create!(title: "B", source_identifier: "y", status: "ready")
    book.chapters.create!(position: 1, title: "one",   duration_seconds: 100, included: true)
    book.chapters.create!(position: 2, title: "two",   duration_seconds: 50,  included: true)
    book.chapters.create!(position: 3, title: "three", duration_seconds: 10,  included: false)

    offsets = book.chapter_offsets
    assert_equal [1, 2], offsets.map { |(chapter, _start)| chapter.position }
    assert_equal [0, 100], offsets.map { |(_chapter, start)| start }
  end

  test "status must be one of the known values" do
    book = Book.new(title: "Z", source_identifier: "z", status: "bogus")
    assert_not book.valid?
  end
end
