class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  inertia_share do
    {
      auth: {
        authenticated: authenticated?.present?,
        email: Current.session&.user&.email_address,
        role: Current.session&.user&.role,
        admin: Current.session&.user&.admin? || false,
        onboarding_required: onboarding_required?
      },
      flash: {
        notice: flash[:notice],
        alert: flash[:alert]
      },
      paths: {
        root: root_path,
        transactions: transactions_path,
        imports: imports_path,
        spending: spending_path,
        budgets: budgets_path,
        subcategories: subcategories_path,
        insights: insights_path,
        ai_preferences: ai_preferences_path,
        settings: settings_path,
        onboarding: onboarding_path,
        admin: admin_root_path,
        ai_controls: admin_ai_controls_path,
        models: admin_models_path,
        jobs: "/admin/jobs",
        session: session_path,
        new_session: new_session_path,
        passwords: passwords_path,
        new_registration: new_registration_path
      }
    }
  end

  private

  def current_user
    Current.user
  end

  def require_admin_user
    return if current_user&.admin?

    redirect_to root_path, alert: "Admin access is required."
  end

  def onboarding_required?
    Current.session&.user&.onboarding_required? || session[:preview_onboarding].present?
  end

  def money_from_cents(cents)
    helpers.number_to_currency(cents.to_i / 100.0)
  end

  def money_from_microdollars(microdollars)
    microdollars = microdollars.to_i
    return helpers.number_to_currency(0) if microdollars.zero?
    return "<$0.01" if microdollars.positive? && microdollars < 10_000

    helpers.number_to_currency(microdollars / 1_000_000.0)
  end

  def ai_request_microdollars(scope)
    scope.sum(:estimated_cost_microdollars) + scope.where(estimated_cost_microdollars: 0).sum(:estimated_cost_cents) * 10_000
  end

  def model_option_props(model)
    {
      id: model.id,
      label: "#{model.name} (#{model.model_id})",
      name: model.name,
      model_id: model.model_id,
      provider: model.provider,
      capabilities: model.capabilities,
      input_modalities: model.input_modalities.presence || [ "unknown" ],
      output_modalities: model.output_modalities.presence || [ "unknown" ],
      context_window_label: model.context_window.present? ? helpers.number_with_delimiter(model.context_window) : nil,
      price_label: model_price_label(model)
    }
  end

  def model_price_label(model)
    input_price = model.input_price_per_million
    output_price = model.output_price_per_million

    input_price.present? || output_price.present? ? "#{helpers.number_to_currency(input_price || 0, precision: 2)} / #{helpers.number_to_currency(output_price || 0, precision: 2)}" : "Unknown"
  end

  def category_props(category)
    return { id: nil, name: "Unclassified", color: "#71717a" } if category.blank?

    {
      id: category.id,
      name: category.name,
      color: category.color.presence || "#52525b",
      monthly_budget_cents: category.monthly_budget_cents
    }
  end

  def category_options(categories = Current.user&.categories&.by_name || Category.none)
    categories.map { |category| category_props(category) }
  end

  def transaction_props(transaction)
    {
      id: transaction.id,
      occurred_on: transaction.occurred_on.iso8601,
      occurred_on_label: transaction.occurred_on.strftime("%b %-d, %Y"),
      short_date_label: transaction.occurred_on.strftime("%b %-d"),
      description: transaction.description,
      merchant_name: transaction.merchant_name,
      description_detail: transaction.description_detail,
      amount_cents: transaction.amount_cents,
      signed_amount_cents: transaction.signed_amount_cents,
      amount_label: transaction.expense? ? money_from_cents(transaction.amount_cents) : "-#{money_from_cents(transaction.amount_cents)}",
      amount_class: transaction.expense? ? "text-foreground" : "text-emerald-600 dark:text-emerald-400",
      direction: transaction.direction,
      category_id: transaction.category_id,
      category: category_props(transaction.category),
      subcategories: transaction.subcategories.by_name.map { |subcategory| subcategory_props(subcategory) },
      notes: transaction.notes,
      classification_reason: transaction.classification_reason,
      confidence_label: transaction.classification_confidence.present? ? "#{(transaction.classification_confidence.to_d * 100).round}%" : "Pending",
      update_path: transaction_path(transaction)
    }
  end

  def subcategory_props(subcategory)
    return nil if subcategory.blank?

    {
      id: subcategory.id,
      name: subcategory.name,
      color: subcategory.color.presence || "#71717a"
    }
  end

  def insight_props(insight)
    {
      id: insight.id,
      title: insight.title,
      body: insight.body,
      severity: insight.severity,
      generation_source: insight.generation_source,
      generation_source_label: insight.generation_source == "ai" ? "AI generated" : "Automatic",
      starts_on: insight.starts_on&.iso8601,
      starts_on_label: insight.starts_on&.strftime("%b %Y"),
      ends_on: insight.ends_on&.iso8601,
      transactions: insight.expense_transactions.includes(:category, :subcategories).recent.limit(25).map { |transaction| transaction_props(transaction) }
    }
  end

  def classification_run_props(classification_run)
    return nil if classification_run.blank?

    {
      id: classification_run.id,
      status: classification_run.status,
      status_label: classification_run.status.humanize,
      active: classification_run.active?,
      cancellable: classification_run.cancellable?,
      processed_count: classification_run.processed_count,
      total_count: classification_run.total_count,
      classified_count: classification_run.classified_count,
      rule_based_count: classification_run.rule_based_count,
      failed_count: classification_run.failed_count,
      progress_percent: classification_run.progress_percent,
      notes: classification_run.notes,
      show_path: classification_run_path(classification_run),
      cancel_path: cancel_classification_run_path(classification_run),
      dismiss_path: dismiss_classification_run_path(classification_run)
    }
  end
end
