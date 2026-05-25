class RefreshRubyLlmModelsJob < ApplicationJob
  queue_as :default

  def perform
    RubyLlmModelImporter.refresh!
  end
end
