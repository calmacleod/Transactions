class ModelsController < ApplicationController
  def index
    RubyLlmModelImporter.ensure_loaded!

    providers = Model.distinct.order(:provider).pluck(:provider)
    provider_counts = Model.group(:provider).count
    models = Model.ordered
                  .by_provider(params[:provider])
                  .matching(params[:query])
    models = models.select { |model| model.capabilities.include?(params[:capability]) } if params[:capability].present?
    models = models.first(250)

    render inertia: {
      stats: {
        available_models: Model.count,
        providers: providers.count,
        structured_output: Model.where("capabilities LIKE ?", "%structured_output%").count,
        vision: Model.where("capabilities LIKE ?", "%vision%").count
      },
      providers: providers.map { |provider| { name: provider, count: provider_counts[provider] } },
      models: models.map { |model| model_props(model) },
      filters: {
        query: params[:query].to_s,
        provider: params[:provider].to_s,
        capability: params[:capability].to_s
      },
      capped: models.size == 250,
      actions: {
        index: models_path,
        refresh: models_path
      }
    }
  end

  def create
    RefreshRubyLlmModelsJob.perform_later

    redirect_to models_path, notice: "Queued RubyLLM model refresh. #{Model.count} models are currently available."
  rescue StandardError => error
    redirect_to models_path, alert: "Model refresh failed: #{error.message}"
  end

  def update
    model = Model.find(params[:id])
    model.update!(model_params)

    redirect_back fallback_location: models_path, notice: "#{model.name} #{model.favorite? ? "favorited" : "removed from favorites"}."
  end

  private

  def model_params
    params.require(:model).permit(:favorite)
  end

  def model_props(model)
    input_price = model.input_price_per_million
    output_price = model.output_price_per_million

    {
      id: model.id,
      name: model.name,
      model_id: model.model_id,
      family: model.family,
      provider: model.provider,
      favorite: model.favorite?,
      update_path: model_path(model),
      input_modalities: model.input_modalities.presence || [ "unknown" ],
      output_modalities: model.output_modalities.presence || [ "unknown" ],
      capabilities: model.capabilities,
      context_window: model.context_window,
      context_window_label: model.context_window.present? ? helpers.number_with_delimiter(model.context_window) : nil,
      price_label: input_price.present? || output_price.present? ? "#{helpers.number_to_currency(input_price || 0, precision: 2)} / #{helpers.number_to_currency(output_price || 0, precision: 2)}" : "Unknown"
    }
  end
end
