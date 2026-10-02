# Roundhouse native compilation experiment

## Purpose

Run Transactions as a native executable while keeping the Rails application
as its source and retaining SQLite and the existing Svelte/Inertia frontend.
The experiment started with [Roundhouse's Rust target](https://github.com/rubys/roundhouse),
then moved to [Spinel Ruby](https://github.com/matz/spinel). This branch contains
app changes, reproducible compiler patches, native framework adapters and
functional checks. It measures compatibility; no performance advantage is claimed.

See [STATUS.md](STATUS.md) for the exact checks and remaining gaps. The fresh
October 2 v8 build passed all navigation pages, all 15 action groups, account
checks, Chromium navigation, local configured-provider protocols and a default-GC
memory soak. Strict compilation and the shared runtime gradual-type gate remain
failing. The refresh uses merged compiler repairs and moves Date support out of
the app adapter into the compiler runtime.

## Compile and run

The scripts target macOS ARM with Ruby 4.0.5/Bundler, npm, Python 3, Git,
Apple Clang/make, Rust 1.98.1 and Homebrew ICU4C at `/opt/homebrew/opt/icu4c`
(tested with ICU 78.3). Setup downloads dependencies into ignored `tmp/roundhouse`.
Install ICU with `brew install icu4c` if necessary.

Run from the repository root:

```sh
bundle install
npm install
# Needed for the browser and configured-AI verification scripts:
npx playwright install chromium
export RUST_MIN_STACK=33554432
experiments/roundhouse/experiment setup
experiments/roundhouse/experiment setup-spinel
experiments/roundhouse/experiment setup-native-deps
experiments/roundhouse/experiment native-smoke

experiments/roundhouse/experiment spinel-native spinel-native-local
bundle exec ruby experiments/roundhouse/seed-native tmp/roundhouse/spinel-native-local --fixtures
PORT=3901 experiments/roundhouse/experiment spinel-run spinel-native-local
```

Open <http://127.0.0.1:3901/>. The disposable login is
`spinel@example.test` / `spinel-local-experiment`. It uses the normal password
check, signed session, authentication filters and dashboard destination.
Requested return URLs are preserved. There is no Imports landing workaround.

Each generated tree has its own SQLite database and signing secret. The seed
command requires a successfully generated tree containing `config/schema.rb`;
it does not create or compile that tree. It leaves the Rails development database
alone. `--fixtures` adds disposable records for the verification scripts.
Choose a new `spinel-native-<name>` for each build; existing output is preserved.
The executable is `<generated tree>/build/bin/blog`. Stop it with Ctrl-C.

The threaded server logs status, method, path and response duration to stderr,
including failed requests. Timings use a monotonic clock and cover body
consumption, dispatch and the response write. Idle keep-alive time is excluded;
WebSocket entries separately measure upgrade dispatch.
To keep a console log and follow it from a second terminal:

```sh
PORT=3901 experiments/roundhouse/experiment spinel-run spinel-native-local \
  > tmp/roundhouse/logs/native-dev-server.log 2>&1
# In another terminal:
tail -n 30 -F tmp/roundhouse/logs/native-dev-server.log
```

Native invitation, password-reset and reminder mail is written to
`<generated tree>/storage/mail/*.json`. Set `NATIVE_APP_URL` when the URL used
by the recipient differs from the loopback default. Provider keys and optional
`OPENAI_API_BASE`, `ANTHROPIC_API_BASE`, `GEMINI_API_BASE` overrides must be
exported in the native server's environment. The native process does not load
Rails dotenv files automatically.

## Memory protection

Every build and native run uses `guard`, which samples the RSS of the whole
child process tree, kills it at its ceiling/deadline, and cleans up descendants.
The server defaults to **512 MiB**. Native compilation defaults to **1 GiB**;
toolchain builds default to **2 GiB**. Rust and C compilation use one worker.
The Roundhouse build uses optimization level 0 with 256 codegen units to reduce
build memory. The full library-test compilation still exceeded the 2 GiB guard;
it was stopped and has no passing result.
Debug symbols are omitted because they substantially increase build memory.

```sh
# Optional tighter/shorter run:
PORT=3901 NATIVE_MAX_RSS_MB=384 NATIVE_MAX_SECONDS=300 \
  experiments/roundhouse/experiment spinel-run spinel-native-local
```

The driver uses Spinel's upstream generational-GC default without setting
`SPINEL_GC_MINOR`. To compare full marking explicitly, prefix the run command with
`SPINEL_GC_MINOR=0`. The final v8 default-GC soak passed 2,100 reads and 420
completed no-key chat jobs, plus polls: RSS samples were 101.8–116.0 MiB and
final-half growth was 3.4 MiB against the unchanged `<8 MiB` assertion.
A finite soak cannot prove every input or operation leak-free. `guard` is a
sampling ceiling, not an OS memory reservation; allow headroom for allocation
spikes. [STATUS.md](STATUS.md) records current measurements and historical GC
comparisons.

## Verification

For the no-key action and memory checks, start the server without provider keys
in one terminal. Stop any existing server on port 3901 first:

```sh
env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GEMINI_API_KEY \
  PORT=3901 experiments/roundhouse/experiment spinel-run spinel-native-local
```

Run the verifiers from another terminal:

```sh
experiments/roundhouse/verify-native http://127.0.0.1:3901 tmp/roundhouse/spinel-native-local
# Restart the native server between authentication-heavy verifier commands.
experiments/roundhouse/verify-actions http://127.0.0.1:3901 tmp/roundhouse/spinel-native-local
# Restart again before the next verifier.
experiments/roundhouse/verify-account http://127.0.0.1:3901 tmp/roundhouse/spinel-native-local
# Restart before browser/memory checks; use the new native PID below.
experiments/roundhouse/guard --max-rss-mb 1024 --seconds 60 -- \
  node experiments/roundhouse/verify-browser.mjs http://127.0.0.1:3901
# Restart before the soak to measure a fresh process.
# Use the native PID printed by the server, not the guard PID:
experiments/roundhouse/verify-memory http://127.0.0.1:3901 <native-pid> \
  --batches 20 --requests 100 --jobs 20
```

Run the page verifier first: the write checks change the fixture database.
Dashboard and credit assertions compare live SQLite records so repeated imports
do not rely on fixed fixture totals.
The app permits ten sign-in attempts per three minutes. Consecutive account
and authentication checks can reach that legitimate limit. Stop the server
with Ctrl-C and rerun the same `spinel-run` command between these suites,
preserving the database. Restart before the memory check and use its new native
PID; a redirect from a rate-limited login fails setup before any workload runs.
The checks assert normal login, requested return URLs, all navigation pages,
assets/PWA, transaction filters and edits, budgets/tags, saved filters,
settings/onboarding, model controls, CSV preview/classification/download/commit,
classification and insight jobs, local chat fallback, invitations, password
reset, account isolation and session revocation. A failed assertion fails the
command; printed HTTP 500s are never counted as passes.

With other native servers stopped, test configured AI against local stubs:

```sh
experiments/roundhouse/verify-ai tmp/roundhouse/spinel-native-local
```

This starts its own guarded server with fake keys and loopback provider
endpoints. It checks budget, spending and search tools across all three protocols,
structured insight editing, normal browser login and live authenticated chat
updates. Chromium has a separate 1 GiB ceiling and closes after the check.
Real paid provider execution remains a separate verification step.

For focused regressions in the original Rails app:

```sh
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/transactions_controller_test.rb \
  test/services/ai_insight_generator_test.rb
```

To inspect the remaining compiler diagnostics:

```sh
experiments/roundhouse/experiment check
experiments/roundhouse/experiment spinel-strict
```

Both diagnostic commands currently exit unsuccessfully: the recorded check has
15 errors and strict Spinel emission has 22 type errors. They are separate from
the runnable survey build and its passing native functional checks. Full Rails
tests can be run with `PARALLEL_WORKERS=1 bin/rails test`; the complete local CI
and full compiler suites are not recorded as passing in this checkpoint.

## Toolchains and compatibility

The driver pins the latest upstream revisions fetched for this run on
October 2, 2026, so another checkout can reproduce the tested build:

- Roundhouse: `e74a81da1fa9d465f6d0daac12483c1e0837f4e5`, plus `roundhouse.patch`.
- Spinel: `7ca803c957565e40436155edaab47cf1cdd4b960`, plus `spinel-compiler.patch`.
- bcrypt: `a78ea0bfae6760c3143ea3b96bcd1594c82d6b7d`.
- jemalloc: 5.3.0, downloaded with a SHA-256 check.

The compiler patches are applied to isolated checkouts under `tmp/roundhouse`.
The merged route-ordering, form-coercion and literal scoped-creation fixes are
used directly from upstream. The remaining patch covers relation/association
behavior, residual parameters, dynamic scoped creation, typed Date support,
normalization/authentication, collection inference, Data constants, runtime
block signatures, bounded batches, contextual keyword defaults and decimal
lowering. Spinel still needs focused C code-generation repairs.
`prepare-spinel` adds native Inertia, mail, provider and persistent job adapters.
The old Date adapter and Date/Time substitutions, native Time wrapper, String
truncation source replacement and four Insights RBS downgrades are removed.
Ordinary app `sig/` declarations describe external gem APIs while keeping
opaque results `untyped`; native adapters still provide their implementations.

Strict Roundhouse compilation still reports compatibility errors. Runtime
inference passes Bar A, but the Bar B gradual-type count exceeds its unchanged
ceiling (562 sites against 519). The runnable build uses
`--survey --allow-unsupported`, then applies the recorded adapters.
The native job monitor replaces the mounted Mission Control engine; mail uses
a local spool; Inertia props are evaluated eagerly. These are explicit runtime
adaptations, not full Rails/gem parity. See [SPINEL.md](SPINEL.md) for the gap ledger.
[RUST.md](RUST.md) preserves the original Rust failures; Rust was not rerun.

Generated projects, binaries, dependency caches, databases and detailed logs
remain in ignored `tmp/roundhouse/`. Reproduction scripts and patches are tracked in the experiment branch.
