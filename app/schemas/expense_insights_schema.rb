class ExpenseInsightsSchema < RubyLLM::Schema
  array :insights do
    object do
      string :title, description: "Short insight headline"
      string :body, description: "One or two sentence explanation grounded in the supplied data"
      string :severity, enum: %w[info warning success], description: "Tone for the insight"
    end
  end
end
