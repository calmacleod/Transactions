ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "json"
require_relative "test_helpers/session_test_helper"

system("bin/vite build", out: File::NULL, err: File::NULL) || abort("Vite test build failed")

module ActiveSupport
  class TestCase
    include ActiveJob::TestHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module InertiaTestHelper
  def inertia_page
    node = css_select('script[data-page="app"]').first
    assert node, "Expected an Inertia page payload"
    JSON.parse(node.text)
  end

  def inertia_props
    inertia_page.fetch("props")
  end
end

class ActionDispatch::IntegrationTest
  include InertiaTestHelper
end
