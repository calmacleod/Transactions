class TransactionClassificationSchema < RubyLLM::Schema
  string :category, description: "Best matching personal finance category"
  number :confidence, description: "Confidence from 0.0 to 1.0"
  string :reason, description: "Short explanation for the category choice"
end
