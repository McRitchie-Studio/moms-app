module Librivox
  # Canned data so tests and offline demos exercise the whole pipeline without
  # touching the network. Mirrors the real archive.org shape for
  # `adventures_sherlockholmes_1007_librivox`.
  class MockClient
    def fetch_book(identifier)
      Librivox::Client::BookData.new(
        identifier: identifier,
        title: "The Adventures of Sherlock Holmes",
        author: "Sir Arthur Conan Doyle",
        narrator: "Mark F. Smith",
        description: "LibriVox recording of The Adventures of Sherlock Holmes, by Sir Arthur Conan Doyle.",
        cover_url: nil,
        full_duration_seconds: 40_483,
        source_url: "https://archive.org/details/#{identifier}",
        chapters: [
          Librivox::Client::ChapterData.new(position: 1, title: "A Scandal in Bohemia",  url: "https://example.test/01.mp3", duration_seconds: 3474.52, size_bytes: 55_595_320),
          Librivox::Client::ChapterData.new(position: 2, title: "The Red-Headed League",  url: "https://example.test/02.mp3", duration_seconds: 3600.09, size_bytes: 57_604_408),
          Librivox::Client::ChapterData.new(position: 3, title: "A Case of Identity",     url: "https://example.test/03.mp3", duration_seconds: 2400.00, size_bytes: 30_000_000)
        ]
      )
    end
  end
end
