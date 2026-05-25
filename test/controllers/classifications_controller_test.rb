require "test_helper"

class ClassificationsControllerTest < ActionDispatch::IntegrationTest
  test "queues transaction classification" do
    sign_in_as users(:one)

    assert_enqueued_with(job: ClassifyTransactionsJob) do
      post classifications_path
    end

    assert_redirected_to root_path
  end
end
