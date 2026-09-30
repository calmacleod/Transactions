# Merchant data

`merchants.json` is a compact, generated subset of the OpenStreetMap Name Suggestion Index, version 8.0.20260918. It contains 13,058 brand/type entries relevant to the app's budgeting categories. It includes international aliases and Wikidata IDs where available, but excludes unrelated map features.

Source: https://github.com/osmlab/name-suggestion-index

Release JSON: https://cdn.jsdelivr.net/npm/name-suggestion-index@8.0.20260918/dist/json/nsi.json

License: BSD-3-Clause; the upstream copyright, terms, and disclaimer are retained in `LICENSE.md`.

`metadata.source_sha256` identifies the exact source JSON used to generate this snapshot. The category mapping and extraction logic live in `app/services/transaction_classification/catalog_builder.rb`.

Refresh with `bin/rails 'merchants:refresh[VERSION]'`, review the generated diff, and commit the snapshot and license together. This is a maintenance operation; runtime classification does not fetch remote data.
