admin_email = ENV["ADMIN_EMAIL"]
admin_password = ENV["ADMIN_PASSWORD"]
admin = nil

if admin_email.present? && admin_password.present?
  admin = User.find_or_initialize_by(email_address: admin_email)
  admin.password = admin_password
  admin.role = "admin"
  admin.onboarding_dismissed_at ||= Time.current
  admin.save!
  puts "Seeded admin user #{admin.email_address}."
else
  puts "Skipping admin user seed. Set ADMIN_EMAIL and ADMIN_PASSWORD to create or update an admin user."
end

category_scope = admin&.categories || Category
subcategory_scope = admin&.transaction_subcategories || TransactionSubcategory

User::DEFAULT_CATEGORIES.each do |name, color, monthly_budget_cents|
  category_scope.find_or_create_by!(name:) do |category|
    category.color = color
    category.monthly_budget_cents = monthly_budget_cents
  end
end

User::DEFAULT_SUBCATEGORIES.each do |name, color|
  subcategory_scope.find_or_create_by!(name:) do |subcategory|
    subcategory.color = color
  end
end

RubyLlmModelImporter.load_cached! if RubyLlmModelImporter.model_table_ready?

seed_csv_path = ENV["SEED_CSV_PATH"]
if Rails.env.development? && seed_csv_path.present? && File.exist?(seed_csv_path)
  seed_user = admin || User.admins.first || User.first
  File.open(seed_csv_path) do |file|
    batch = StatementCsvImporter.new(io: file, filename: File.basename(seed_csv_path), user: seed_user).call
    Ai::TransactionClassifier.new(user: seed_user).classify_all(batch.expense_transactions.unclassified)
    Ai::InsightGenerator.new(user: seed_user).call(
      start_date: seed_user&.expense_transactions&.minimum(:occurred_on) || ExpenseTransaction.minimum(:occurred_on),
      end_date: seed_user&.expense_transactions&.maximum(:occurred_on) || ExpenseTransaction.maximum(:occurred_on)
    )
  end
end
