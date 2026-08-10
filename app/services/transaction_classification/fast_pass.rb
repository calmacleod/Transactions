module TransactionClassification
  class FastPass
    BATCH_SIZE = 500

    Result = Data.define(:category_name, :confidence, :reason)

    def initialize(run:, batch_size: BATCH_SIZE, rulebook: Rulebook.new)
      @run = run
      @batch_size = batch_size
      @rulebook = rulebook
    end

    def call(scope)
      run.start!(total: scope.count)
      return run.complete! if run.total_count.zero?

      scope.select(:id, :description, :direction).find_in_batches(batch_size:) do |transactions|
        run.reload
        return run.cancel! if run.cancel_requested?

        results_by_id = transactions.index_with { |transaction| classify(transaction) }
        categories_by_name = ensure_categories(results_by_id.values.map(&:category_name).uniq)
        apply_results(results_by_id, categories_by_name)
        record_progress(results_by_id)
      end

      run.reload.cancel_requested? ? run.cancel! : run.complete!
    rescue StandardError => error
      run.fail!(error)
      raise
    end

    private

    attr_reader :run, :batch_size, :rulebook

    def ensure_categories(names)
      names.each_with_object({}) do |name, categories|
        categories[name] = category_scope.find_or_create_by!(name:) do |category|
          category.color = CategoryColor.pick(name)
        end
      end
    end

    def classify(transaction)
      result = rulebook.call(description: transaction.description, direction: transaction.direction)
      Result.new(category_name: result.category_name, confidence: result.confidence, reason: result.reason)
    end

    def apply_results(results_by_id, categories_by_name)
      classified_at = Time.current

      results_by_id.group_by { |_id, result| result }.each do |result, pairs|
        ExpenseTransaction.where(id: pairs.map(&:first)).update_all(
          category_id: categories_by_name.fetch(result.category_name).id,
          classification_confidence: result.confidence,
          classification_reason: result.reason,
          classified_at:,
          updated_at: classified_at
        )
      end
    end

    def record_progress(results_by_id)
      run.record_batch!(
        processed: results_by_id.size,
        classified: results_by_id.size,
        rule_based: results_by_id.size,
        ai: 0,
        failed: 0
      )
    end

    def category_scope
      run.user&.categories || Category.all
    end
  end
end
