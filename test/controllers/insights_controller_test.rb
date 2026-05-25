require "test_helper"

class InsightsControllerTest < ActionDispatch::IntegrationTest
  test "queues recent insight generation" do
    sign_in_as users(:one)

    assert_enqueued_with(job: GenerateInsightsJob) do
      post insights_path
    end

    assert_redirected_to root_path
  end
end
