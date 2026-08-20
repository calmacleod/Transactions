require "test_helper"

class NewRelicTest < ActiveSupport::TestCase
  test "instruments Inertia rendering events" do
    assert_equal %w[
      render.inertia_rails
      resolve_props.inertia_rails
      ssr.inertia_rails
    ], NewRelic::Agent.config[:active_support_custom_events_names]
  end
end
