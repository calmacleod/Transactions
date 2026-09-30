# Roundhouse → native Spinel experiment

The modified app **compiles to a native macOS ARM executable** using the
pinned toolchains and compatibility patches in this directory. It starts on
`http://127.0.0.1:3901` with a separate SQLite database. This is a successful
native build, but the generated application still has runtime gaps.

Verified September 30, 2026:

| Check | Result |
| --- | --- |
| Roundhouse survey emission + prepared Spinel build | Exit 0; native executable produced |
| Native `/up` | HTTP 200 |
| Native `/session/new` and frontend assets | HTTP 200; Svelte sign-in form rendered |
| JSON sign-in, signed session cookie, Inertia JSON response | Passed with the isolated experiment account; direct and dashboard-entry sign-in now land on Imports |
| Native `/imports` | HTTP 200; signed in through the browser and rendered Imports |
| Native dashboard `/`, `/transactions`, `/budgets` | HTTP 500; generated relation/date support remains incomplete |
| Roundhouse strict emission after the app changes | Exit 1; 36 type errors |
| Rails tests | 209 runs, 1,080 assertions, zero failures/errors/skips |
| RuboCop on 22 changed/new app and test files | No offenses |
| Native compiler and ICU normalization smoke checks | Passed |

The executable currently lives at `tmp/roundhouse/spinel-native/build/bin/blog`.
It is approximately 10 MB, built at `-O 0 --no-inline-hot` with one C compiler
job. This experiment measures compatibility, not performance.

## Changes needed for compilation

The Rails source changes retain the tested Rails behavior while making the
code easier to resolve statically:

- Keep string keys consistent when merging permitted transaction attributes.
- Name result data classes uniquely and retain their existing aliases.
- Use explicit token readers instead of a runtime `public_send` method name.
- Use explicit accumulators in the affected generic enumeration blocks.
- Pass IDs to the affected route helpers; avoid a private helper name that
  Roundhouse mistook for a route helper or a parameter hash.
- Express top-level admin controllers using an admin path/helper scope.
- Use `redirect_back_or_to` and explicit authentication keyword arguments.
- Rank merchant groups by their integer cents before formatting dollars.
- Give the reminder job an explicit nil return after its side effects.

`prepare-spinel` patches only generated output. It corrects contradictory RBS
hints and loads a small native compatibility layer for pagination, view helpers,
Unicode normalization, authentication helpers, health checks, and Inertia page
rendering. It also handles JSON request bodies and binds the native server to
loopback. The generated post-login destination uses Imports for a direct
sign-in or a stored dashboard URL, avoiding the known dashboard failure.
Other stored return paths are retained. The Rails sign-in behavior is unchanged.
The existing Vite/Svelte frontend is reused.

`spinel-compiler.patch` contains four compiler fixes required by this app:
Time values in closure cells, a truncated hash-merge C expression, volatile
String slot lending across rescue, and hash coercion using an inlined result's
type instead of the enclosing method's type. `compiler-smoke.rb` exercises
Time capture, String mutation through a rescued slot, and string-keyed grouping
inside a symbol-keyed return. `unicode-smoke.rb` checks canonical/compatibility
normalization and independence of returned String storage.

## Reproduce

Toolchains are pinned to:

- Roundhouse `3f5753ad4d35cffbfe6b619257d728d06ea80deb`.
- Spinel `438241961cd7e9f0e1dc1cb81f261dd37cb9d756`, with the saved patch.
- bcrypt `a78ea0bfae6760c3143ea3b96bcd1594c82d6b7d`.
- jemalloc 5.3.0, downloaded with a SHA-256 check and installed under `tmp/`.

Roundhouse's build script embeds absolute paths to its native runtime.
Reusing Cargo artifacts after moving the toolchain checkout produced an
empty embedded file table and `missing runtime/spinel/scaffold/` during
transpilation. `setup` now cleans Roundhouse's package artifacts before
rebuilding, while retaining the dependency cache.

This driver targets this Mac's Homebrew layout and uses installed ICU4C
(`/opt/homebrew/opt/icu4c`, currently 78.3), Ruby/Bundler, npm, Apple Clang,
and Rust 1.97.1 for building Roundhouse. Setup needs network access when
sources are not already cached.

```sh
experiments/roundhouse/experiment setup
experiments/roundhouse/experiment setup-spinel
experiments/roundhouse/experiment setup-native-deps
experiments/roundhouse/experiment native-smoke

# A fresh output name preserves every earlier generated tree.
experiments/roundhouse/experiment spinel-native spinel-native-rebuild
bundle exec ruby experiments/roundhouse/seed-native tmp/roundhouse/spinel-native-rebuild
PORT=3901 experiments/roundhouse/experiment spinel-run spinel-native-rebuild
```

In another terminal:

```sh
experiments/roundhouse/verify-native
```

The verifier asserts the working health/login/asset/session paths, follows
the login redirect for both direct and dashboard-entry sign-in, and prints
the current statuses of the other routes. It does **not** treat those printed
route probes as successful functional tests.

The disposable login is `spinel@example.test` / `spinel-local-experiment`.
Sign in directly or visit `/imports` to reach the working Imports page.
An older generated executable will still redirect a direct sign-in to the
failing dashboard; generate a fresh output tree to pick up the landing fix.
The experiment uses its own `storage/development.sqlite3` and generated signing
secret; it does not use the Rails development database, environment secrets,
or real account credentials. The server is one process, with two Spinel workers
by default. Stop it with Ctrl-C.

## Remaining runtime limitations

The dashboard tries to call `includes` on an emitted Array; transactions calls
`ordered` on an emitted Array; budgets reaches an undefined `Date` constant.
These are observed HTTP failures in the generated runtime. Roundhouse's strict
analysis still rejects this stack, so the build deliberately uses survey output
and explicit compatibility adjustments.

The remaining strict diagnostics include these coverage and inference gaps:

| Area | Examples reported by Roundhouse |
| --- | --- |
| Relations and aggregates | Missing relation `to_a`/`to_sql`, `expense_transaction_ids`, and seed `minimum`/`maximum`; inconsistent relation/Array inference. |
| Dates and ranges | Missing `Date::DAYNAMES` enumeration/fetch and integer range `map`; date values inferred as integers; nullable Time comparison. |
| Imports and uploads | Uploaded files modeled as hashes, missing Active Storage `download`, and month-group tuple destructuring inferred incorrectly. |
| JSON and model metadata | Incorrect `fetch` result types, missing `deep_symbolize_keys`, sanitizer resolution, `index_with`, nullable numeric `to_d`, and RubyLLM model pricing. |
| Framework integration | Missing `InertiaRails.defer` and an unresolved mailer layout instance variable. |

These are diagnostics from the pinned compiler against the modified app;
they describe the generated/static model, not failures in the Rails test run.
The native `/service-worker.js` route also returned HTTP 500 because
`PwaController` was missing from its generated runtime.

Other unverified gaps include RubyLLM/provider execution, date ranges and
aggregates, classification, background-job persistence, and Mission Control.
In particular, methods declared in `Data.define` blocks were not preserved
in the emitted classification result classes. The native Inertia adapter eagerly evaluates lazy
props and does not implement the complete deferred/partial/version protocol.
Its password-reset tokens belong to the isolated native app, not the Rails
app's token format. A successful build does not establish full Rails parity.

Full evidence is saved under `tmp/roundhouse/logs/`, including
`spinel-native-transpile.log`, `spinel-native-build.log`/`.exit`,
`native-http.log`, `native-http-login.log`, `rails-tests.log`, and the
compiler/Unicode smoke build logs. The login follow-up compiled into
`spinel-native-login`; its HTTP checks covered direct sign-in, a stored
dashboard URL, and preservation of an Imports URL with query parameters.
Earlier failed iterations remain under `tmp/roundhouse/spinel-app-v*/`.
The original Rust results are recorded in [RUST.md](RUST.md) and have not been
rerun. The [experiment overview](README.md) is the entry point for this branch.
