module ApplicationHelper
  def money_from_cents(cents)
    number_to_currency(cents.to_i / 100.0)
  end

  def transaction_money(transaction)
    amount = money_from_cents(transaction.amount_cents)
    transaction.expense? ? amount : "-#{amount}"
  end

  def transaction_amount_class(transaction)
    transaction.expense? ? "text-slate-900" : "text-emerald-700"
  end

  def category_badge(category)
    return tag.span("Unclassified", class: "rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-600") if category.blank?

    tag.span(class: "inline-flex items-center gap-1.5 rounded-full bg-white px-2.5 py-1 text-xs font-medium text-slate-700 ring-1 ring-slate-200") do
      safe_join([
        tag.span("", class: "size-2 rounded-full", style: "background-color: #{category.color || '#64748b'}"),
        category.name
      ])
    end
  end

  def confidence_label(transaction)
    return "Pending" if transaction.classification_confidence.blank?

    "#{(transaction.classification_confidence.to_d * 100).round}%"
  end
end
