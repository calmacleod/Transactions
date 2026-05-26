require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "application layout exposes install metadata" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_includes response.body, 'content="width=device-width,initial-scale=1,viewport-fit=cover"'
    assert_includes response.body, 'rel="manifest" href="/manifest.json"'
    assert_includes response.body, 'name="color-scheme" content="light"'
    assert_includes response.body, 'name="theme-color" content="#0f172a"'
    assert_includes response.body, 'name="msapplication-TileColor" content="#0f172a"'
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
    assert_equal "#0f172a", manifest.fetch("theme_color")
    assert_equal "#f8fafc", manifest.fetch("background_color")
    assert manifest.fetch("icons").any? { |icon| icon["src"] == "/icon.svg" && icon["sizes"] == "any" }
    assert manifest.fetch("icons").any? { |icon| icon["sizes"] == "512x512" && icon["purpose"] == "maskable" }
  end

  test "localhost redirect preserves pwa file extensions" do
    host! "127.0.0.1"

    get pwa_manifest_path(format: :json)
    assert_redirected_to "http://localhost/manifest.json"

    get pwa_service_worker_path(format: :js)
    assert_redirected_to "http://localhost/service-worker.js"
  end

  test "service worker is available" do
    get pwa_service_worker_path

    assert_response :success
    assert_includes response.body, "self.addEventListener(\"install\""
    assert_includes response.body, "self.addEventListener(\"fetch\""
  end
end
