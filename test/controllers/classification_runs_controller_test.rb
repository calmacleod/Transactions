require "test_helper"

class ClassificationRunsControllerTest < ActionDispatch::IntegrationTest
  test "shows classification progress" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "running", total_count: 10, processed_count: 4, classified_count: 4, rule_based_count: 4)

    get classification_run_path(run)

    assert_response :success
    props = inertia_props.fetch("classification_run")
    assert_equal 4, props["processed_count"]
    assert_equal 10, props["total_count"]
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

  test "requests cancellation through Inertia redirect" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "running")

    patch cancel_classification_run_path(run), headers: { "X-Inertia" => "true" }

    assert_redirected_to root_path
    assert_equal "canceling", run.reload.status
  end

  test "dismisses classification progress for the session" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "complete", total_count: 0, finished_at: Time.current)

    patch dismiss_classification_run_path(run)

    assert_redirected_to root_path

    get root_path

    assert_response :success
    assert_nil inertia_props["classification_run"]
  end

  test "dismisses classification progress through Inertia redirect" do
    sign_in_as users(:one)
    run = ClassificationRun.create!(status: "complete", total_count: 0, finished_at: Time.current)

    patch dismiss_classification_run_path(run), headers: { "X-Inertia" => "true" }

    assert_redirected_to root_path
  end
end
