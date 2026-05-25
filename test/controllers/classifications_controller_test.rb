require "test_helper"

class ClassificationsControllerTest < ActionDispatch::IntegrationTest
  test "queues transaction classification" do
    sign_in_as users(:one)

    assert_difference -> { ClassificationRun.count }, 1 do
      post classifications_path
    end

    run = ClassificationRun.latest.first
    assert_enqueued_with(job: ClassifyTransactionsJob, args: [ run.id ])
    assert_equal ExpenseTransaction.unclassified.count, run.total_count
    assert_redirected_to root_path
  end

  test "does not queue a second active classification" do
    sign_in_as users(:one)
    ClassificationRun.create!(status: "running")

    assert_no_difference -> { ClassificationRun.count } do
      post classifications_path
    end

    assert_redirected_to root_path
  end

  test "queues transaction classification with turbo stream" do
    sign_in_as users(:one)

    assert_difference -> { ClassificationRun.count }, 1 do
      post classifications_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "turbo-stream action=\"replace\" target=\"classification_run\""
    assert_includes response.body, "Queued fast classification"
  end
end
