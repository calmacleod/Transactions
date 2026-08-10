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
  rescue ActiveRecord::RecordInvalid => error
    redirect_back fallback_location: admin_models_path, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def model_params
    params.require(:model).permit(:favorite, :user_selectable)
  end

  def sorted_models(scope)
    return sort_models_by_price(scope) if sort_field == "price"

    scope.order(sort_order)
  end

  def sort_order
    primary, fallback = case sort_field
    when "user_access"
      [ sorted_column(:user_selectable), [ sortable_column(:name).asc ] ]
    when "model"
      [ sorted_column(:name), [ sortable_column(:provider).asc ] ]
    when "provider"
      [ sorted_column(:provider), [ sortable_column(:name).asc ] ]
    when "context"
      [ sorted_column(:context_window), [ sortable_column(:name).asc ] ]
    else
      [ sorted_column(:favorite), [ sortable_column(:provider).asc, sortable_column(:name).asc ] ]
    end

    [ primary, *fallback ]
  end

  def sortable_column(column)
    Model.arel_table[column]
  end

  def sorted_column(column)
    attribute = sortable_column(column)
    sort_direction == "asc" ? attribute.asc : attribute.desc
  end

  def sort_models_by_price(scope)
    scope.to_a.sort_by do |model|
      price = model_input_price(model)
      comparable_price = price || 0

      [
        price.nil? ? 1 : 0,
        sort_direction == "asc" ? comparable_price : -comparable_price,
        model.name.downcase
      ]
    end
  end

  def model_input_price(model)
    standard_pricing = model.pricing&.dig("text_tokens", "standard") || model.pricing&.dig(:text_tokens, :standard) || {}
    value = standard_pricing["input_per_million"] || standard_pricing[:input_per_million]

    BigDecimal(value.to_s) if value
  rescue ArgumentError
    nil
  end

  def sort_field
    %w[favorite user_access model provider context price].include?(params[:sort]) ? params[:sort] : "favorite"
  end

  def sort_direction
    params[:direction] == "asc" ? "asc" : "desc"
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
