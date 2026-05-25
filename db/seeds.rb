[
  [ "Groceries", "#059669", 800_00 ],
  [ "Restaurants", "#dc2626", 450_00 ],
  [ "Shopping", "#2563eb", 300_00 ],
  [ "Subscriptions", "#9333ea", 250_00 ],
  [ "Pets", "#7c3aed", 200_00 ],
  [ "Entertainment", "#c2410c", 150_00 ],
  [ "Transportation", "#0891b2", 250_00 ],
  [ "Health", "#be185d", 200_00 ],
  [ "Home", "#0f766e", 500_00 ],
  [ "Travel", "#4f46e5", 400_00 ],
  [ "Payments", "#16a34a", nil ],
  [ "Refunds & Credits", "#0d9488", nil ],
  [ "Uncategorized", "#64748b", nil ]
].each do |name, color, monthly_budget_cents|
  Category.find_or_create_by!(name:) do |category|
    category.color = color
    category.monthly_budget_cents = monthly_budget_cents
  end
end

admin_email = ENV["ADMIN_EMAIL"]
admin_password = ENV["ADMIN_PASSWORD"]

if admin_email.present? && admin_password.present?
  admin = User.find_or_initialize_by(email_address: admin_email)
  admin.password = admin_password
  admin.save!
  puts "Seeded admin user #{admin.email_address}."
else
  puts "Skipping admin user seed. Set ADMIN_EMAIL and ADMIN_PASSWORD to create or update an admin user."
end

seed_csv_path = ENV["SEED_CSV_PATH"]
if Rails.env.development? && seed_csv_path.present? && File.exist?(seed_csv_path)
  File.open(seed_csv_path) do |file|
    batch = StatementCsvImporter.new(io: file, filename: File.basename(seed_csv_path)).call
    Ai::TransactionClassifier.new.classify_all(batch.expense_transactions.unclassified)
    Ai::InsightGenerator.new.call(
      start_date: ExpenseTransaction.minimum(:occurred_on),
      end_date: ExpenseTransaction.maximum(:occurred_on)
    )
  end
end
