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
end
