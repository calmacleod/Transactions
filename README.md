# Transactions

A Rails 8 + SQLite expense tracker for headerless credit card CSV exports.

## Features

- Headerless CSV import in the format `date, description, debit, credit, card`.
- Local SQLite storage for transactions, import batches, categories, and generated insights.
- RubyLLM-backed transaction classification with structured output.
- RubyLLM-backed spending insight generation with a rule-based fallback when no AI provider key is configured.
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

Without a provider key, the app still imports data and uses transparent local merchant rules for basic classification.

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

Kamal loads `.kamal/secrets`, fetches the Bitwarden project with `kamal secrets fetch --adapter bitwarden-sm`, and extracts these values with `kamal secrets extract`.
