class ModelsController < ApplicationController
  before_action :require_admin_user

  def index
    RubyLlmModelImporter.ensure_loaded!

    providers = Model.distinct.order(:provider).pluck(:provider)
    provider_counts = Model.group(:provider).count
    models = sorted_models(Model.by_provider(params[:provider]).matching(params[:query]))
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
      sort: {
        field: sort_field,
        direction: sort_direction
      },
      capped: models.size == 250,
      actions: {
        index: admin_models_path,
        refresh: admin_models_path
      }
    }
  end

  def create
    before_count = Model.count
    RubyLlmModelImporter.refresh!
    after_count = Model.count
    delta = after_count - before_count

    redirect_to admin_models_path, notice: "Model registry refreshed. #{after_count} models available (#{delta >= 0 ? "+" : ""}#{delta})."
  rescue StandardError => error
    redirect_to admin_models_path, alert: "Model refresh failed: #{error.message}"
  end

  def update
    model = Model.find(params[:id])
    model.update!(model_params)

    redirect_back fallback_location: admin_models_path, notice: "#{model.name} updated."
  end

  private

  def model_params
    params.require(:model).permit(:favorite, :user_selectable)
  end

  def sorted_models(scope)
    scope.order(sort_order)
  end

  def sort_order
    column, fallback = case sort_field
    when "user_access"
      [ "user_selectable", "name ASC" ]
    when "model"
      [ "name", "provider ASC" ]
    when "provider"
      [ "provider", "name ASC" ]
    when "context"
      [ "context_window", "name ASC" ]
    when "price"
      [ "CAST(json_extract(pricing, '$.text_tokens.standard.input_per_million') AS REAL)", "name ASC" ]
    else
      [ "favorite", "provider ASC, name ASC" ]
    end

    Arel.sql("#{column} #{sort_direction_sql}, #{fallback}")
  end

  def sort_field
    %w[favorite user_access model provider context price].include?(params[:sort]) ? params[:sort] : "favorite"
  end

  def sort_direction
    params[:direction] == "asc" ? "asc" : "desc"
  end

  def sort_direction_sql
    sort_direction.upcase
  end

  def model_props(model)
    {
      id: model.id,
      name: model.name,
      model_id: model.model_id,
      family: model.family,
      provider: model.provider,
      favorite: model.favorite?,
      user_selectable: model.user_selectable?,
      update_path: admin_model_path(model),
      input_modalities: model.input_modalities.presence || [ "unknown" ],
      output_modalities: model.output_modalities.presence || [ "unknown" ],
      capabilities: model.capabilities,
      context_window: model.context_window,
      context_window_label: model.context_window.present? ? helpers.number_with_delimiter(model.context_window) : nil,
      price_label: model_price_label(model)
    }
  end
end
