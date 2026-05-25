require "test_helper"

class ClassificationRunsControllerTest < ActionDispatch::IntegrationTest
  test "shows classification progress" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "running", total_count: 10, processed_count: 4, classified_count: 4, rule_based_count: 4)

    get classification_run_path(run)

    assert_response :success
    assert_includes response.body, "4"
    assert_includes response.body, "10 processed"
  end

  test "requests cancellation" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "running")

    patch cancel_classification_run_path(run)

    assert_redirected_to root_path
    assert_equal "canceling", run.reload.status
    assert run.cancel_requested?
  end

  test "cancels without solid queue tables in the test adapter" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "queued", active_job_id: "missing-solid-queue-row")

    patch cancel_classification_run_path(run)

    assert_redirected_to root_path
    assert_equal "canceling", run.reload.status
  end

  test "requests cancellation with turbo stream" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "running")

    patch cancel_classification_run_path(run), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal "canceling", run.reload.status
    assert_includes response.body, "turbo-stream action=\"replace\" target=\"classification_run\""
    assert_includes response.body, "Classification stop requested."
  end

  test "dismisses classification progress for the session" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "complete", total_count: 0, finished_at: Time.current)

    patch dismiss_classification_run_path(run)

    assert_redirected_to root_path

    get root_path

    assert_response :success
    assert_no_match %r{<h2 class="panel-title">Classification</h2>}, response.body
  end

  test "dismisses classification progress with turbo stream" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "complete", total_count: 0, finished_at: Time.current)

    patch dismiss_classification_run_path(run), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "turbo-stream action=\"replace\" target=\"classification_run\""
  end
end
