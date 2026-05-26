# AGENTS.md

Guidance for coding agents working in this repository.

## Project Summary

Transactions is a Rails 8.1 + SQLite expense tracker for headerless credit card CSV exports. It uses Rails built-in authentication, Solid Queue/Cache/Cable, Mission Control Jobs, RubyLLM-backed classification and insight generation, Inertia Rails, Svelte 5, Vite, Tailwind CSS, and local shadcn-svelte style components.

The app is intentionally local-first: imports, transactions, categories, subcategories, classification runs, AI requests/settings, and insights are stored in SQLite.

## High-Value Paths

- `app/controllers/` - Rails controllers, Inertia prop assembly, authentication-protected flows.
- `app/controllers/application_controller.rb` - shared Inertia props and serializer-style helpers for categories, transactions, insights, and classification runs.
- `app/models/` - Active Record models for transactions, imports, categories, AI settings/requests, sessions, and classification runs.
- `app/services/` - CSV import, dashboard summaries, RubyLLM model import, AI controls, classifier, chat, insight generation, and fast-pass classification.
- `app/queries/transaction_filter.rb` - transaction filtering/search logic.
- `app/jobs/` - Solid Queue jobs for classification, insight generation, and model refresh.
- `app/javascript/pages/` - Svelte Inertia pages.
- `app/javascript/layouts/AppLayout.svelte` - shared authenticated app shell/navigation/theme handling.
- `app/javascript/lib/components/ui/` - local reusable UI components, mostly shadcn-svelte style wrappers.
- `app/javascript/entrypoints/application.css` - Tailwind/theme CSS entrypoint.
- `test/` - Minitest coverage, including service, model, controller, integration, and Playwright e2e tests.
- `config/routes.rb` - route map, including `/admin/jobs` for Mission Control Jobs.
- `config/initializers/ruby_llm.rb` and `config/initializers/ruby_llm_model_registry.rb` - RubyLLM setup.
- `config/deploy.yml`, `.kamal/secrets`, `.kamal/hooks/` - Kamal deploy configuration.

## Commands

Setup:

```bash
bundle install
npm install
bin/rails db:setup
```

Run locally:

```bash
bin/dev
```

`Procfile.dev` starts both Rails (`bin/rails server`) and Vite (`bin/vite dev`). Open `http://localhost:3000`. Routes redirect `127.0.0.1` to `localhost` so the browser uses the same host as Vite.

Focused Rails tests:

```bash
bin/rails test test/services/statement_csv_importer_test.rb
bin/rails test test/controllers/transactions_controller_test.rb
```

E2E tests:

```bash
npm run test:e2e
npm run test:e2e:headed
```

Build frontend assets:

```bash
npm run build
```

Style/security/full CI:

```bash
bin/rubocop
bin/bundler-audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/ci
```

`bin/ci` runs setup, RuboCop, bundler-audit, Brakeman, Vite build, Rails tests, Playwright, and seed replant.

## Testing Notes

- Rails uses Minitest, not RSpec.
- `test/test_helper.rb` runs `bin/vite build` before Rails tests. A failing or stale frontend build can break otherwise backend-focused tests.
- Tests run in parallel with fixtures loaded from `test/fixtures/*.yml`.
- Controller/integration tests can parse Inertia responses with `inertia_page` and `inertia_props`.
- Playwright config starts a test Rails server on port `3100` unless `PLAYWRIGHT_BASE_URL` is set. It prepares the test database and loads fixtures.
- Prefer focused tests first, then broaden to `bin/ci` only when the change has enough surface area to justify it.

## Frontend Conventions

- Svelte pages live under `app/javascript/pages`, with shared components under `app/javascript/pages/components` and `app/javascript/lib/components/ui`.
- Use the `$lib` alias for imports from `app/javascript/lib`.
- Prefer existing local UI components and patterns before adding new component dependencies.
- Use `@lucide/svelte` icons for icon buttons and navigation icons.
- App navigation, theme toggling, and authenticated chrome are centralized in `AppLayout.svelte`.
- Inertia links usually use `@inertiajs/svelte` `Link`; full reload links are used where Rails engines or non-Inertia pages need them, such as Mission Control Jobs.
- Keep UI changes dense and task-focused. This is an expense-control application, so operational clarity should win over marketing-style layouts.

## Rails Conventions

- Authentication is Rails built-in auth, wired through `app/controllers/concerns/authentication.rb` and `Current.session`.
- Shared Inertia props are declared in `ApplicationController#inertia_share`.
- For user-facing data passed to Svelte, prefer the existing prop helper pattern in `ApplicationController` unless a narrower controller-local shape is clearly better.
- Money is stored as cents.
- CSV imports expect headerless rows: `date, description, debit, credit, card`.
- Keep transaction filtering in `TransactionFilter` rather than scattering query logic across controllers.
- AI behavior should degrade when provider keys are absent. The app has local/rule-based fallbacks for basic classification and insights.
- Background work uses Solid Queue and is visible through Mission Control Jobs at `/admin/jobs`.

## Environment And Secrets

Development and test use `dotenv-rails`. Copy `.env.example` to `.env` or `.env.local`; do not commit real secrets.

Required for seeded admin login:

- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`

Optional AI/provider keys:

- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GEMINI_API_KEY`
- `OPENAI_API_BASE`
- `RUBYLLM_MODEL`

Optional development seed input:

- `SEED_CSV_PATH`

Optional deploy helper:

- `BWS_ACCESS_TOKEN`

## Deployment Notes

Deployment uses Kamal and Bitwarden Secrets Manager through `.kamal/secrets`.

Before diagnosing a production mismatch, verify the active branch, whether local commits have been pushed, and what revision Kamal actually deployed. Prior deploy debugging found a case where the local branch was ahead of `origin/master`, so a missing UI/admin change after deploy may be a revision mismatch rather than an app-code issue.

Kamal/Bitwarden secrets expected by README:

- `KAMAL_SERVER_IP`
- `KAMAL_APP_HOST`
- `RAILS_MASTER_KEY`
- `ADMIN_EMAIL`
- `ADMIN_PASSWORD`
- `OPENAI_API_KEY`

Common deploy commands:

```bash
export BWS_ACCESS_TOKEN=...
bin/kamal setup
bin/kamal deploy
```

## Agent Workflow

- Start with `git status --short` and preserve user changes.
- Keep diffs narrow; avoid opportunistic refactors.
- Use `rg` for code search.
- Match existing Rails, Svelte, Tailwind, and local component patterns.
- Add focused regression tests for behavior changes.
- Do not claim AI-provider behavior was tested unless real provider keys were present or the test stubs the provider path directly.
- Avoid touching `todo.txt` unless the user specifically asks; it may be local scratch work.
