require "test_helper"

class BookImporterTest < ActiveSupport::TestCase
  def importer
    BookImporter.new(client: Librivox::MockClient.new)
  end

  test "imports metadata and flags the first N chapters as included" do
    book = importer.import("sherlock", limit: 2)

    assert_equal "The Adventures of Sherlock Holmes", book.title
    assert_equal "Sir Arthur Conan Doyle", book.author
    assert_equal "Mark F. Smith", book.narrator
    assert_equal "digesting", book.status
    assert_equal 3, book.chapters.count
    assert_equal [1, 2], book.included_chapters.map(&:position)
    assert_equal "A Scandal in Bohemia", book.chapters.first.title
  end

  test "is idempotent and re-flags included chapters for the same identifier" do
    b1 = importer.import("sherlock", limit: 1)
    b2 = importer.import("sherlock", limit: 2)

    assert_equal b1.id, b2.id
    assert_equal 3, b2.chapters.count
    assert_equal [1, 2], b2.included_chapters.map(&:position)
  end

  test "a nil limit marks every chapter as included (whole book)" do
    book = importer.import("sherlock", limit: nil)
    assert_equal [1, 2, 3], book.included_chapters.map(&:position)
  end
end
