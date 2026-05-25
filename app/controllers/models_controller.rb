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
    RubyLlmModelImporter.refresh!

    redirect_to models_path, notice: "RubyLLM models refreshed. #{Model.count} models are available."
  rescue StandardError => error
    redirect_to models_path, alert: "Model refresh failed: #{error.message}"
  end
end
