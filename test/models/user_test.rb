require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "rejects an ambiguous preferred model id" do
    attributes = {
      model_id: "shared-model",
      name: "Shared Model",
      capabilities: Model::APP_CAPABILITIES,
      modalities: { input: [ "text" ], output: [ "text" ] },
      user_selectable: true
    }
    Model.create!(**attributes, provider: "openai")
    Model.create!(**attributes, provider: "anthropic")

    users(:two).preferred_ai_model = "shared-model"

    assert_not users(:two).valid?
    assert_includes users(:two).errors[:preferred_ai_model], "must uniquely identify a user-selectable text model with tools and structured output"
  end
end
