module TransactionClassification
  class PublicMerchantCatalog
    PATH = Rails.root.join("vendor/merchant_data/merchants.json")
    GENERIC_NAMES = %w[bank cafe coffee food fuel gas hotel market pharmacy restaurant shop store supermarket].freeze

    Match = Data.define(:identity, :name, :category_name)

    def initialize(path: PATH)
      @path = path
    end

    def call(description)
      key = MerchantName.normalize(description)
      candidates = index.fetch(key.split.first, []).select do |alias_key, _match|
        key == alias_key || (alias_key.length >= 4 && key.start_with?("#{alias_key} "))
      end
      return if candidates.empty?

      longest = candidates.map { |alias_key, _match| alias_key.length }.max
      best_candidates = candidates.select { |alias_key, _match| alias_key.length == longest }
      matches = best_candidates.map(&:last)
      return unless matches.map(&:category_name).uniq.one?

      # A shared/rebranded name can establish a merchant type without establishing a brand identity.
      unless matches.map(&:identity).uniq.one?
        canonical = matches.find { |match| MerchantName.normalize(match.name) == best_candidates.first.first } || matches.first
        return Match.new(identity: nil, name: canonical.name, category_name: canonical.category_name)
      end

      matches.first
    end

    private

    def index
      return @index if @index

      data = JSON.parse(File.read(@path))
      raise TypeError, "Expected catalog object" unless data.is_a?(Hash)

      merchants = data.fetch("merchants")
      raise TypeError, "Expected merchant entries" unless merchants.is_a?(Array) && merchants.all? { |merchant| valid_entry?(merchant) }

      @index = merchants.each_with_object({}) do |merchant, result|
        match = Match.new(identity: merchant.fetch("id"), name: merchant.fetch("name"), category_name: merchant.fetch("category"))
        merchant.fetch("aliases").each do |name|
          key = MerchantName.normalize(name)
          next if key.length < 2 || GENERIC_NAMES.include?(key)

          (result[key.split.first] ||= []) << [ key, match ]
        end
      end
    rescue Errno::ENOENT, JSON::ParserError, KeyError, TypeError => error
      Rails.logger.warn("Public merchant catalog unavailable: #{error.class}")
      @index = {}
    end

    def valid_entry?(merchant)
      merchant.is_a?(Hash) && %w[id name category].all? { |key| merchant[key].is_a?(String) && merchant[key].present? } &&
        merchant["aliases"].is_a?(Array) && merchant["aliases"].all? { |name| name.is_a?(String) }
    end
  end
end
