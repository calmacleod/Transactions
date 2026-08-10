class ExpenseInsightsSchema < RubyLLM::Schema
  array :insights do
    object do
      string :finding_key, description: "Exact key of one supplied candidate finding"
      string :title, description: "Short decision-oriented headline grounded in that candidate"
      string :body, description: "One or two sentences explaining why the comparison matters without repeating the headline"
      string :action, description: "One concrete next step supported by the finding"
    end
  end
end
