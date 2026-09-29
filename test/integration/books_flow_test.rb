require "test_helper"

class BooksFlowTest < ActionDispatch::IntegrationTest
  def sign_in_as(role)
    user = User.create!(email: "#{role}@example.com", name: role.capitalize, role: role)
    post link_consume_path(token: Studio::Link.create_magic_link(email: user.email).token)
    assert_equal user.id, session[Studio.session_key]
    user
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

  test "an admin sees the digest button and the form" do
    sign_in_as("admin")

    get books_path
    assert_select "a[href=?]", new_book_path

    get new_book_path
    assert_response :success
    assert_select "form"
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
