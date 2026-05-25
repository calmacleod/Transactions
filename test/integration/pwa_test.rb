require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "application layout exposes install metadata" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_includes response.body, 'content="width=device-width,initial-scale=1,viewport-fit=cover"'
    assert_includes response.body, 'rel="manifest" href="/manifest.json"'
    assert_includes response.body, 'name="theme-color" content="#f3f4f0"'
    assert_includes response.body, 'name="msapplication-TileColor" content="#f3f4f0"'
    assert_includes response.body, 'name="apple-mobile-web-app-capable" content="yes"'
    assert_includes response.body, 'name="apple-mobile-web-app-status-bar-style" content="black-translucent"'
  end

  test "manifest is installable" do
    get pwa_manifest_path(format: :json)

    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal "Transactions", manifest.fetch("name")
    assert_equal "Transactions", manifest.fetch("short_name")
    assert_equal "/", manifest.fetch("start_url")
    assert_equal "standalone", manifest.fetch("display")
    assert_equal "#f3f4f0", manifest.fetch("theme_color")
    assert manifest.fetch("icons").any? { |icon| icon["sizes"] == "512x512" && icon["purpose"] == "maskable" }
  end

  test "service worker is available" do
    get pwa_service_worker_path

    assert_response :success
    assert_includes response.body, "self.addEventListener(\"install\""
    assert_includes response.body, "self.addEventListener(\"fetch\""
  end
end
