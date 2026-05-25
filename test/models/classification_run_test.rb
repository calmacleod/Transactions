require "test_helper"

class ClassificationRunTest < ActiveSupport::TestCase
  test "tracks progress percentage" do
    run = ClassificationRun.new(total_count: 10, processed_count: 4)

    assert_equal 40, run.progress_percent
  end

  test "can request cancellation while active" do
    run = ClassificationRun.create!(status: "running")

    run.request_cancel!

    assert_equal "canceling", run.status
    assert run.cancel_requested?
  end
end
