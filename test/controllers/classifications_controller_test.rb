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

  test "queues transaction classification through Inertia redirect" do
    sign_in_as users(:one)

    assert_difference -> { ClassificationRun.count }, 1 do
      post classifications_path, headers: { "X-Inertia" => "true" }
    end

    assert_redirected_to root_path
  end
end
