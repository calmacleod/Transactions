# Run with: RAILS_ENV=test bin/rails runner script/benchmark_response_time.rb
# Synthetic records are rolled back; no production or development data is used.
require "json"
abort "This benchmark requires RAILS_ENV=test" unless Rails.env.test?

Rails.logger.level = Logger::ERROR
ActiveRecord::Base.transaction do
  user = User.create!(email_address: "performance-audit@example.test", password: "password", role: "admin")
  categories = 12.times.map { |index| user.categories.create!(name: "Audit category #{index}", color: "#64748b", monthly_budget_cents: 50_000) }
  rows = 10_000.times.map do |index|
    { user_id: user.id, category_id: index % 10 == 0 ? nil : categories[index % categories.size].id,
      occurred_on: Date.current - index % 500, amount_cents: 100 + index % 20_000,
      direction: index % 20 == 0 ? "credit" : "debit", description: "AUDIT MERCHANT #{index % 50}  LOCATION",
      external_id: "performance-audit-#{index}", raw_data: { cells: [ "synthetic" ] * 50 }, source: "performance-audit" }
  end
  ExpenseTransaction.insert_all!(rows)
  transaction_ids = user.expense_transactions.order(:id).limit(2000).ids
  6.times do |index|
    insight = user.insights.create!(title: "Audit finding #{index}", body: "Synthetic performance evidence", action: "Review evidence", severity: "info", starts_on: Date.current.beginning_of_month)
    InsightTransaction.insert_all!(transaction_ids.map { |id| { insight_id: insight.id, expense_transaction_id: id, user_id: user.id } })
  end
  client = ActionDispatch::Integration::Session.new(Rails.application)
  client.host! "www.example.com"
  client.post "/session", params: { email_address: user.email_address, password: "password" }
  results = [ "/", "/transactions", "/spending", "/insights", "/offline/snapshot.json" ].map do |path|
    samples = 6.times.map do
      queries = 0
      records = 0
      sql_callback = ->(*args) { queries += 1 unless args.last[:name] == "SCHEMA" || args.last[:cached] }
      record_callback = ->(*args) { records += args.last[:record_count] }
      GC.start
      allocations = GC.stat(:total_allocated_objects)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      ActiveSupport::Notifications.subscribed(sql_callback, "sql.active_record") do
        ActiveSupport::Notifications.subscribed(record_callback, "instantiation.active_record") do
          client.get path, headers: { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version, "Accept" => "text/html" }
          raise "Unexpected HTTP #{client.response.status} for #{path}" unless client.response.status == 200
        end
      end
      { ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2),
        queries:, records:, allocations: GC.stat(:total_allocated_objects) - allocations,
        bytes: client.response.body.bytesize, status: client.response.status }
    end.drop(1)
    { path:, median_ms: samples.map { |sample| sample[:ms] }.sort[2], sample: samples.last }
  end
  puts JSON.pretty_generate(results)
  raise ActiveRecord::Rollback
end
