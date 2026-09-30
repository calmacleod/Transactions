require "net/http"
require "tempfile"

namespace :merchants do
  desc "Refresh the bundled offline merchant catalog from a versioned Name Suggestion Index release"
  task :refresh, [ :version ] => :environment do |_task, args|
    version = args[:version].presence || JSON.parse(File.read(TransactionClassification::PublicMerchantCatalog::PATH)).fetch("metadata").fetch("version")
    abort "Expected a release version such as 8.0.20260918" unless version.match?(/\A\d+\.\d+\.\d+\z/)

    download = lambda do |filename|
      uri = URI("https://cdn.jsdelivr.net/npm/name-suggestion-index@#{version}/#{filename}")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 30) do |http|
        http.get(uri.request_uri)
      end
      raise "Merchant data download failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    catalog = TransactionClassification::CatalogBuilder.build(download.call("dist/json/nsi.json"))
    raise "Unexpected merchant release" unless JSON.parse(catalog).fetch("metadata").fetch("version") == version

    license = download.call("LICENSE.md")
    raise "Unexpected merchant license" unless license.include?("BSD 3-Clause")

    # All downloads and validation complete before replacing the working snapshot.
    directory = TransactionClassification::PublicMerchantCatalog::PATH.dirname
    { "LICENSE.md" => license, "merchants.json" => catalog }.each do |filename, contents|
      Tempfile.create("merchant-catalog", directory) do |file|
        file.write(contents)
        file.close
        File.rename(file.path, directory.join(filename))
      end
    end
    puts "Refreshed merchant catalog to #{version}. Review and commit vendor/merchant_data."
  end
end
