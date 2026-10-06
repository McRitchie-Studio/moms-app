ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # The magic-link rate limit counts in Solid Cache rows
    # (ClosedSignup::MagicLinkRequest::STORE). A transactional test rolls them
    # back anyway; clearing also covers one that is not, so a test's requests
    # never depend on how many ran before it.
    setup { ClosedSignup::MagicLinkRequest::STORE.clear }
  end
end
