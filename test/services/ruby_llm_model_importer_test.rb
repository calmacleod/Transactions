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
end
