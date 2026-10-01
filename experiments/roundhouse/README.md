# Roundhouse native compilation experiment

## Purpose

Run Transactions as a native executable while keeping the Rails application
as its source and retaining SQLite and the existing Svelte/Inertia frontend.
The experiment started with [Roundhouse's Rust target](https://github.com/rubys/roundhouse),
then moved to [Spinel Ruby](https://github.com/matz/spinel). This branch contains
app changes, reproducible compiler patches, native framework adapters and
functional checks. It measures compatibility; no performance advantage is claimed.

See [STATUS.md](STATUS.md) for the checkpoint's working behavior, known failures
and exact tested/untested scope. Transactions still has a date-related 500 in
some browser requests even though the seeded navigation checks pass.

## Compile and run

The scripts target macOS ARM with Ruby 4.0.5/Bundler, npm, Python 3, Git,
Apple Clang/make, Rust 1.97.1 and Homebrew ICU4C at `/opt/homebrew/opt/icu4c`
(tested with ICU 78.3). Setup downloads dependencies into ignored `tmp/roundhouse`.
Install ICU with `brew install icu4c` if necessary.

Run from the repository root:

```sh
bundle install
npm install
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
Debug symbols are omitted because they substantially increase build memory.

```sh
# Optional tighter/shorter run:
PORT=3901 NATIVE_MAX_RSS_MB=384 NATIVE_MAX_SECONDS=300 \
  experiments/roundhouse/experiment spinel-run spinel-native-local
```

The native driver defaults to `SPINEL_GC_MINOR=0`: garbage collection remains
active, using full marking. The generational mode encountered an invalid
remembered/pinned-cell fault in this workload. Changing that setting needs a
new memory and stability check. `guard` is a sampling ceiling, not an OS memory
reservation; allow some headroom for short allocation spikes.

A two-stage authenticated soak exercised 3,140 reads and 680 completed no-key
chat jobs on one server. The first stage failed its growth assertion after a
step to about 190 MiB; the longer continuation passed the unchanged assertion,
ending near 163 MiB with 0.6 MiB growth in its final half. This is evidence for
the tested workload, not proof that every possible operation is leak-free.
Current build/run measurements and remaining gaps are in [SPINEL.md](SPINEL.md).

## Verification

With the native server running in one terminal:

```sh
experiments/roundhouse/verify-native http://127.0.0.1:3901 tmp/roundhouse/spinel-native-local
experiments/roundhouse/verify-actions http://127.0.0.1:3901 tmp/roundhouse/spinel-native-local
experiments/roundhouse/verify-account http://127.0.0.1:3901 tmp/roundhouse/spinel-native-local
experiments/roundhouse/guard --max-rss-mb 1024 --seconds 60 -- \
  node experiments/roundhouse/verify-browser.mjs http://127.0.0.1:3901
# Use the native PID printed by the server, not the guard PID:
experiments/roundhouse/verify-memory http://127.0.0.1:3901 <native-pid>
# Also exercise the persistent job thread; requires no provider keys:
experiments/roundhouse/verify-memory http://127.0.0.1:3901 <native-pid> --jobs 20
```

Run the page verifier first: the write checks change the fixture database.
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
For Rails regressions, use `PARALLEL_WORKERS=1 bin/rails test`.

## Toolchains and compatibility

The driver pins the latest upstream revisions fetched for this run on
October 1, 2026, so another checkout can reproduce the tested build:

- Roundhouse: `3219450199e45b23bb716acdb63edbea01fd2714`, plus `roundhouse.patch`.
- Spinel: `65121d29b14d7095d5172f50f232ee839332aab6`, plus `spinel-compiler.patch`.
- bcrypt: `a78ea0bfae6760c3143ea3b96bcd1594c82d6b7d`.
- jemalloc: 5.3.0, downloaded with a SHA-256 check.

The compiler patches are applied to isolated checkouts under `tmp/roundhouse`.
They cover relation/association behavior, typed form parameters, scoped record
creation, collection-route precedence, date/decimal lowering, keyword binding,
class declarations and C code generation. `prepare-spinel` adds the app's native
Inertia, calendar, mail, provider and persistent job adapters.

Strict Roundhouse compilation still reports compatibility errors. The runnable
build uses `--survey --allow-unsupported`, then applies the recorded adapters.
The native job monitor replaces the mounted Mission Control engine; mail uses
a local spool; Inertia props are evaluated eagerly. These are explicit runtime
adaptations, not full Rails/gem parity. See [SPINEL.md](SPINEL.md) for the gap ledger.
[RUST.md](RUST.md) preserves the original Rust failures; Rust was not rerun.

Generated projects, binaries, dependency caches, databases and detailed logs
remain in ignored `tmp/roundhouse/`. Reproduction scripts and patches are committed.
