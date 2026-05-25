class ModelsController < ApplicationController
  def index
    RubyLlmModelImporter.ensure_loaded!

    @providers = Model.distinct.order(:provider).pluck(:provider)
    @provider_counts = Model.group(:provider).count
    @models = Model.ordered
                   .by_provider(params[:provider])
                   .matching(params[:query])
    @models = @models.select { |model| model.capabilities.include?(params[:capability]) } if params[:capability].present?
    @models = @models.first(250)
  end

  def create
    RefreshRubyLlmModelsJob.perform_later

    redirect_to models_path, notice: "Queued RubyLLM model refresh. #{Model.count} models are currently available."
  rescue StandardError => error
    redirect_to models_path, alert: "Model refresh failed: #{error.message}"
  end
end
