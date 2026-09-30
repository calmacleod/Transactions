require "test_helper"

class RubyLlmModelImporterTest < ActiveSupport::TestCase
  test "loads cached RubyLLM models into the database" do
    Model.delete_all

    RubyLlmModelImporter.load_cached!

    assert_operator Model.count, :>, 0
    assert Model.exists?(provider: "openai")
  end

  test "ensure_loaded only imports when the registry is empty" do
    Model.delete_all
    RubyLlmModelImporter.ensure_loaded!
    imported_count = Model.count

    RubyLlmModelImporter.ensure_loaded!

    assert_equal imported_count, Model.count
  end

  test "catalog updates preserve model ids favorites and user access" do
    RubyLlmModelImporter.load_cached!
    model = Model.find_by!(provider: "openai", model_id: "gpt-5-nano")
    model.update!(favorite: true, user_selectable: true)
    original_id = model.id
    original_count = Model.count

    RubyLlmModelImporter.load_cached!

    assert_equal original_count, Model.count
    assert_equal original_id, model.reload.id
    assert_predicate model, :favorite?
    assert_predicate model, :user_selectable?
    assert model.price(:input).present?
  end
end
