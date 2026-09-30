require "test_helper"

class ModelTest < ActiveSupport::TestCase
  test "model search handles blank queries and filters by name" do
    literal = Model.create!(provider: "openai", model_id: "scope_%_model", name: "Literal wildcard")
    Model.create!(provider: "openai", model_id: "scope_other_model", name: "Other model")

    assert_equal Model.count, Model.matching(nil).count
    assert_equal Model.count, Model.matching(" ").count
    assert_equal [ literal.id ], Model.matching("Literal wildcard").pluck(:id)
    assert_includes Model.matching("Literal").pluck(:id), literal.id
  end
end
