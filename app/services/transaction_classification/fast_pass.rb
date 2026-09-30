module TransactionClassification
  class FastPass
    BATCH_SIZE = 500

    def initialize(run:, batch_size: BATCH_SIZE, rulebook: Rulebook.new, catalog: PublicMerchantCatalog.new)
      @run = run
      @batch_size = batch_size
      @classifier = MerchantClassifier.new(user: run.user, rulebook:, catalog:)
    end

    def call(scope)
      scope = scope.automatically_classifiable
      run.start!(total: scope.count)
      return run.complete! if run.total_count.zero?

      scope.select(:id, :description, :direction).find_in_batches(batch_size:) do |transactions|
        run.reload
        return run.cancel! if run.cancel_requested?

        results_by_id = transactions.index_with { |transaction| classify(transaction) }
        categories_by_name = ensure_categories(results_by_id.values.map(&:category_name).uniq)
        classified_count = apply_results(results_by_id, categories_by_name)
        record_progress(results_by_id, classified_count)
      end

      run.reload.cancel_requested? ? run.cancel! : run.complete!
    rescue StandardError => error
      run.fail!(error)
      raise
    end

    private

    attr_reader :run, :batch_size, :classifier

    def ensure_categories(names)
      names.each_with_object({}) do |name, categories|
        categories[name] = category_scope.find_or_create_by!(name:) do |category|
          category.color = CategoryColor.pick(name)
        end
      end
    end

    def classify(transaction)
      classifier.call(description: transaction.description, direction: transaction.direction)
    end

    def apply_results(results_by_id, categories_by_name)
      classified_at = Time.current

      classified_count = 0
      results_by_id.group_by { |_id, result| result }.each do |result, pairs|
        classified_count += ExpenseTransaction.where(id: pairs.map(&:first)).automatically_classifiable.update_all(
          category_id: categories_by_name.fetch(result.category_name).id,
          classification_confidence: result.confidence,
          classification_reason: result.reason,
          classification_source: result.source,
          classified_at:,
          updated_at: classified_at
        )
      end
      classified_count
    end

    def record_progress(results_by_id, classified_count)
      run.record_batch!(
        processed: results_by_id.size,
        classified: classified_count,
        rule_based: classified_count,
        ai: 0,
        failed: 0
      )
    end

    def category_scope
      run.user&.categories || Category.all
    end
  end
end
