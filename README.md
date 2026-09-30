# Transactions

A Rails 8 + SQLite expense tracker for headerless credit card CSV exports.

## Features

- Headerless CSV import in the format `date, description, debit, credit, card`.
- Local SQLite storage for transactions, import batches, categories, and generated insights.
- RubyLLM-backed transaction classification with structured output.
- Import classification learns from your manual categories and identifies merchants using a bundled, free OpenStreetMap Name Suggestion Index catalog.
- RubyLLM-backed spending insight generation with a rule-based fallback when no AI provider key is configured.
- New Relic application performance monitoring, distributed tracing, and log forwarding in production.
- Inertia Rails + Svelte dashboard and transaction review UI using local shadcn-svelte style components.
- Rails-generated Docker, Thruster, Solid Queue/Cache/Cable, and Kamal configuration.

## Setup

```bash
bundle install
npm install
bin/rails db:setup
bin/dev
```

Open `http://localhost:3000`.

Run the browser UI checks with:

```bash
npm run test:e2e
```

## Admin Login

The app is protected by Rails 8 built-in authentication. Seed the admin account from environment variables:

```bash
cp .env.example .env
$EDITOR .env
bin/rails db:seed
```

Both `ADMIN_EMAIL` and `ADMIN_PASSWORD` are required to create or update the admin user.

Development and test load `.env` files through `dotenv-rails`. Keep real local values in `.env` or `.env.local`; both are ignored by Git.

## AI Configuration

RubyLLM is configured in `config/initializers/ruby_llm.rb`.

Set at least one provider key before using AI classification or insight generation:

```bash
$EDITOR .env
```

Optional provider environment variables:

- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GEMINI_API_KEY`
- `OPENAI_API_BASE`

Import previews and fast classification work without provider keys or network requests. They use your manual category history, the bundled public merchant catalog, and local merchant rules. The separate AI classifier can use a configured provider for remaining unknown transactions.

## Merchant Classification

Manual categories take priority over public merchant types and rules. Merchant matching normalizes punctuation, accents, common processor prefixes (`SQ *`, `TST*`, `PAYPAL*`, `PP*`, `SP*`), and store numbers. Public brand identities and aliases let a manual category apply across branches of the same brand. History stays within the current user's transactions and is loaded once per classifier run, without a recent-row cutoff. Conflicting manual categories or public merchant types fall back to other evidence instead of copying an arbitrary match. If a name identifies multiple brands with the same merchant type, that type can still suggest a category, but it does not establish a shared brand identity. Credits retain their payment/refund treatment.

Category changes on the Transactions page, bulk edits, and import-preview selections are recorded as manual choices. Automatic suggestions keep their confidence, explanation, and source when committed, so they do not become manual training data. An import-preview category selection is protected from later background classification updates.

The migration marks old categorized rows without classification metadata as `legacy`, and rows with automatic metadata as `automatic`. Unambiguous legacy matches remain available at lower confidence, with an explanation that their source is unknown. Old imports discarded provenance, and older manual edits left automatic metadata intact; their true origin cannot be reconstructed reliably. Editing those categories records a confirmed manual choice going forward.

The [Name Suggestion Index](https://github.com/osmlab/name-suggestion-index) provides common brand names, aliases, Wikidata identities, and OpenStreetMap merchant types under BSD-3-Clause. A versioned snapshot and its license are committed in `vendor/merchant_data`, with budgeting categories mapped in `TransactionClassification::CatalogBuilder`. It covers common physical merchants worldwide, not every independent business or online service. Unknown merchants fall back to local rules or remain Uncategorized. No transaction data is sent to the public source.

To refresh the snapshot from a specific published release:

```bash
bin/rails 'merchants:refresh[8.0.20260918]'
```

Omitting the version downloads the currently bundled release again. The task validates downloads before replacing the snapshot; a failed download leaves the working catalog intact. Review and commit the generated catalog and license, then restart the application workers. Imports use the bundled snapshot even if the source is unavailable; a missing or malformed local file falls back to history and rules.

## Email Configuration

Transactional email uses Action Mailer with Resend when `RESEND_API_KEY` is present.

Optional email environment variables:

- `RESEND_API_KEY`
- `MAILER_FROM`

The default sender uses the verified Resend domain `transaction.callummacleod.ca`.
Override `MAILER_FROM` only with another sender on a domain verified in Resend.

## RubyLLM Models

The app stores RubyLLM's model registry locally so available models can be browsed in the UI.

```bash
bin/rails db:seed
```

Seeding imports RubyLLM's packaged model catalog. The app also syncs that packaged catalog on boot so model metadata stays current with the installed RubyLLM version. Use the Models page in the app to browse providers, capabilities, pricing, and context windows, or refresh the registry from RubyLLM/providers when API keys are configured.

## CSV Import

The importer expects headerless rows shaped like this:

```csv
2026-05-22,"SAMPLE ONLINE STORE",17.24,,1111********2222
2026-05-20,"SAMPLE REFUND",,4.99,1111********2222
```

Use the dashboard upload form, or seed a local development CSV with an explicit path:

```bash
SEED_CSV_PATH=/path/to/local/export.csv bin/rails db:seed
```

`SEED_CSV_PATH` is optional and only used in development.

## Kamal

Rails generated the deployment skeleton:

- `Dockerfile`
- `bin/docker-entrypoint`
- `config/deploy.yml`
- `.kamal/secrets`
- `.kamal/hooks/*`

Fill in image, hosts, registry, and secrets later, then deploy with:

```bash
export BWS_ACCESS_TOKEN=your-bitwarden-access-token
bin/kamal setup
bin/kamal deploy
```

Kamal expects these Bitwarden Secrets Manager keys:

- `KAMAL_SERVER_IP`
- `KAMAL_APP_HOST`
- `RAILS_MASTER_KEY`
- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`
- `OPENAI_API_KEY`
- `NEW_RELIC_LICENSE_KEY`
- `RESEND_API_KEY`
- `MAILER_FROM`

Kamal loads `.kamal/secrets`, fetches the Bitwarden project with `kamal secrets fetch --adapter bitwarden-sm`, and extracts these values with `kamal secrets extract`.
