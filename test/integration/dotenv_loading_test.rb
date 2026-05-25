require "test_helper"

class DotenvLoadingTest < ActiveSupport::TestCase
  test "dotenv is available in local environments" do
    assert defined?(Dotenv)
  end
end
