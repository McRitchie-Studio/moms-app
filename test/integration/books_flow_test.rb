require "test_helper"

class BooksFlowTest < ActionDispatch::IntegrationTest
  def sign_in_as(role)
    user = User.create!(email: "#{role}@example.com", name: role.capitalize, role: role)
    post link_consume_path(token: Studio::Link.create_magic_link(email: user.email).token)
    assert_equal user.id, session[Studio.session_key]
    user
  end

  # BookImporter.new answers an importer whose import raises `error`, for the
  # block only (minitest 6 ships no stub).
  def with_importer_raising(error)
    importer = Object.new
    importer.define_singleton_method(:import) { |*, **| raise error }
    BookImporter.define_singleton_method(:new) { |*| importer }
    yield
  ensure
    BookImporter.singleton_class.remove_method(:new)
  end

  test "the library and home are public, and hide every digest link from visitors" do
    [ books_path, root_path ].each do |path|
      get path
      assert_response :success
      assert_select "a[href=?]", new_book_path, count: 0
    end
  end

  # Importing is not public: create downloads a whole book and stitches its audio
  # into storage in the background (found in review 2026-09-28).
  test "an anonymous visitor cannot reach the digest form or import a book" do
    get new_book_path
    assert_redirected_to login_path

    assert_no_difference -> { Book.count } do
      post books_path, params: { identifier: "anything" }
    end
    assert_redirected_to login_path
  end

  test "a signed-in non-admin cannot import a book" do
    sign_in_as("viewer")

    get new_book_path
    assert_redirected_to root_path

    assert_no_difference -> { Book.count } do
      post books_path, params: { identifier: "anything" }
    end
    assert_redirected_to root_path
  end

  test "an admin sees the digest button on home and in the library, and the form" do
    sign_in_as("admin")

    [ root_path, books_path ].each do |path|
      get path
      assert_select "a[href=?]", new_book_path, { text: "Digest a book" }, "digest button on #{path}"
    end

    get new_book_path
    assert_response :success
    assert_select "form"
  end

  test "a failed import is logged for the admin and answered with a redirect" do
    sign_in_as("admin")
    with_importer_raising(IOError.new("archive.org timed out")) do
      assert_difference -> { ErrorLog.count }, 1 do
        post books_path, params: { identifier: "slow-book" }
      end
    end
    assert_redirected_to new_book_path
    assert_equal "Something went wrong importing that book.", flash[:alert]
    assert_match "archive.org timed out", ErrorLog.last.message
  end

  test "a book LibriVox does not have is answered, not logged" do
    sign_in_as("admin")
    with_importer_raising(Librivox::Client::NotFound.new("no such identifier")) do
      assert_no_difference -> { ErrorLog.count } do
        post books_path, params: { identifier: "typo" }
      end
    end
    assert_redirected_to new_book_path
    assert_match "Couldn't find that book", flash[:alert]
  end

  test "a ready book shows the player and chapter seek buttons" do
    book = Book.create!(title: "The Adventures of Sherlock Holmes", source_identifier: "sh",
                        status: "ready", audio_duration_seconds: 7075)
    book.chapters.create!(position: 1, title: "A Scandal in Bohemia",  duration_seconds: 3474, included: true)
    book.chapters.create!(position: 2, title: "The Red-Headed League", duration_seconds: 3600, included: true)
    book.audio.attach(io: StringIO.new("ID3-test-bytes"), filename: "sh.mp3", content_type: "audio/mpeg")

    get book_path(book.slug)
    assert_response :success
    assert_select "audio#book-player"
    assert_select "button", text: /A Scandal in Bohemia/
  end

  test "a digesting book shows the stitching state" do
    book = Book.create!(title: "Pending Book", source_identifier: "pb", status: "digesting")
    get book_path(book.slug)
    assert_response :success
    assert_select "p", text: /Stitching/
  end
end
