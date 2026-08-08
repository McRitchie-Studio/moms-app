require "test_helper"

class BooksFlowTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    token = MagicLink.generate(email: user.email, return_to: nil)
    post magic_link_consume_path(token: token)
  end

  setup do
    @user = User.create!(name: "Mom", email: "mom@example.com")
    sign_in(@user)
  end

  test "library index and the digest form render" do
    get books_path
    assert_response :success

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
