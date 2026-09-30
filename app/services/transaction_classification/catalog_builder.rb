require "digest"

module TransactionClassification
  class CatalogBuilder
    CATEGORY_TYPES = {
      "Groceries" => %w[shop/supermarket shop/convenience shop/grocery shop/greengrocer shop/butcher shop/bakery shop/deli shop/dairy shop/seafood shop/health_food shop/frozen_food shop/nuts shop/spices shop/wholesale],
      "Restaurants" => %w[amenity/restaurant amenity/fast_food amenity/cafe amenity/pub amenity/bar amenity/ice_cream],
      "Pets" => %w[shop/pet amenity/veterinary amenity/animal_boarding],
      "Transportation" => %w[amenity/fuel amenity/charging_station amenity/parking amenity/car_wash amenity/car_rental amenity/car_sharing shop/car_repair shop/car_parts shop/tyres shop/bicycle],
      "Health" => %w[amenity/pharmacy amenity/hospital amenity/clinic amenity/doctors amenity/dentist shop/optician shop/medical_supply leisure/fitness_centre healthcare/physiotherapist healthcare/laboratory],
      "Home" => %w[shop/doityourself shop/hardware shop/furniture shop/houseware shop/garden_centre shop/appliance shop/bed shop/kitchen shop/bathroom_furnishing shop/lighting shop/paint shop/flooring shop/carpet shop/telecommunication office/telecommunication],
      "Entertainment" => %w[amenity/cinema amenity/casino leisure/bowling_alley leisure/amusement_arcade leisure/escape_game leisure/trampoline_park tourism/theme_park],
      "Travel" => %w[tourism/hotel tourism/motel tourism/hostel tourism/caravan_site shop/travel_agency]
    }.freeze

    def self.build(source_json)
      source = JSON.parse(source_json)
      merchants = source.fetch("nsi").flat_map do |path, group|
        next [] unless path.start_with?("brands/")

        type = path.delete_prefix("brands/")
        category = CATEGORY_TYPES.find { |_name, types| types.include?(type) }&.first
        category ||= "Shopping" if type.start_with?("shop/")
        next [] unless category

        group.fetch("items").filter_map do |item|
          tags = item.fetch("tags")
          name = tags["brand:en"].presence || tags["brand"].presence || tags["name:en"].presence || tags["name"].presence
          next unless name

          aliases = tags.select { |key, _| key.match?(/\A(?:brand|name)(?::[a-z]{2,3}(?:-[a-z0-9]+)*)?\z/i) }.values + Array(item["matchNames"])
          {
            "id" => tags["brand:wikidata"].presence || item.fetch("id"),
            "name" => name, "category" => category, "aliases" => aliases.flat_map { |value| value.split(";") }.uniq.sort
          }
        end
      end.uniq.sort_by { |merchant| [ merchant.fetch("name"), merchant.fetch("id"), merchant.fetch("category") ] }
      raise ArgumentError, "Incomplete merchant catalog" if merchants.size < 1_000

      metadata = {
        "source" => "https://github.com/osmlab/name-suggestion-index",
        "version" => source.fetch("_meta").fetch("version"),
        "source_sha256" => Digest::SHA256.hexdigest(source_json),
        "license" => "BSD-3-Clause", "merchant_count" => merchants.size
      }
      "{\n  \"metadata\": #{metadata.to_json},\n  \"merchants\": [\n#{merchants.map { |merchant| "    #{merchant.to_json}" }.join(",\n")}\n  ]\n}\n"
    end
  end
end
