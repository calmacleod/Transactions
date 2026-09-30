module TransactionClassification
  module MerchantName
    PROCESSOR_PREFIX = /\A(?:sq|tst|paypal|pp|sp)\s*\*\s*/i

    def self.normalize(description)
      merchant = description.to_s.sub(PROCESSOR_PREFIX, "")
        .split(/\s{2,}|\s*#\s*\d/, 2).first.to_s

      merchant.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").delete("’'").downcase
        .gsub("&", " and ").gsub(/[^\p{Alnum}]+/, " ").squish
    end
  end
end
