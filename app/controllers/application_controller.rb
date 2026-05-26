class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  inertia_share do
    {
      auth: {
        authenticated: authenticated?.present?,
        email: Current.session&.user&.email_address
      },
      flash: {
        notice: flash[:notice],
        alert: flash[:alert]
      },
      paths: {
        root: root_path,
        transactions: transactions_path,
        spending: spending_path,
        budgets: budgets_path,
        subcategories: subcategories_path,
        insights: insights_path,
        ai_controls: ai_controls_path,
        models: models_path,
        jobs: "/admin/jobs",
        session: session_path,
        new_session: new_session_path,
        passwords: passwords_path
      }
    }
  end

  private

  def money_from_cents(cents)
    helpers.number_to_currency(cents.to_i / 100.0)
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

  def category_options(categories = Category.by_name)
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
      ends_on: insight.ends_on&.iso8601
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
