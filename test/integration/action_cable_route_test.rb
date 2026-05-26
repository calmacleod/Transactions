require "test_helper"

class ActionCableRouteTest < ActionDispatch::IntegrationTest
  test "mounts the websocket endpoint used by the frontend consumer" do
    cable_route = Rails.application.routes.routes.find do |route|
      route.path.spec.to_s == "/cable"
    end

    assert cable_route
    assert_match "ActionCable::Server", cable_route.app.app.class.name
  end
end
