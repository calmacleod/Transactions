# Roundhouse native compilation experiment

## Purpose

Test whether this small Rails expense tracker can be transpiled with
[Roundhouse](https://github.com/rubys/roundhouse) and run locally as a native
executable, while retaining its SQLite data model and Svelte/Inertia frontend.
The experiment started with Rust, then switched to
[Spinel Ruby](https://github.com/matz/spinel) to investigate whether its Ruby
runtime could accommodate more of the existing app.

This branch records the app changes, compiler fixes, generated-code adapters,
reproduction scripts, and regression checks needed to reach a native build.
It tests compilation and basic HTTP behavior; it does not establish feature
parity or a performance advantage over Rails.

## Outcome

Verified September 30, 2026 on macOS ARM:

| Target/check | Result |
| --- | --- |
| Initial Rust survey output | Failed to build: 1,243 errors with the source compiler; 1,244 with the official release. |
| Spinel survey output with saved compatibility changes | Compiled to a native executable and ran locally. |
| Native health, sign-in, assets, session cookies, Inertia JSON | Passed. Imports rendered in the browser. |
| Native dashboard, transactions, budgets | HTTP 500 from incomplete relation/date support. |
| Strict Roundhouse Spinel transpilation | Still fails with 36 type errors. |
| Modified Rails app | 209 tests / 1,080 assertions passed; RuboCop passed on 22 changed/new app and test files. |

The working build uses Roundhouse's `--survey --allow-unsupported` output,
then applies the compatibility adjustments in this directory. Strict
transpilation and a fully functional native app remain separate milestones.
Rust was not rerun after the app changes. Detailed evidence is recorded in
[SPINEL.md](SPINEL.md) and the historical [RUST.md](RUST.md).

## Compile and run locally

Run these commands from the repository root. The tested prerequisites are
Ruby 4.0.5 with Bundler, npm, Python 3, Git, curl, Apple Clang/make, installed
Rust 1.97.1, and Homebrew ICU4C at `/opt/homebrew/opt/icu4c` (tested with 78.3).
The scripts currently target this macOS ARM/Homebrew layout. Install ICU with
`brew install icu4c` if needed. Setup downloads the pinned toolchains and
native dependencies; compilation uses cached dependencies afterward.

```sh
bundle install
npm install

experiments/roundhouse/experiment setup
experiments/roundhouse/experiment setup-spinel
experiments/roundhouse/experiment setup-native-deps
experiments/roundhouse/experiment native-smoke

experiments/roundhouse/experiment spinel-native spinel-native-local
bundle exec ruby experiments/roundhouse/seed-native tmp/roundhouse/spinel-native-local
PORT=3901 experiments/roundhouse/experiment spinel-run spinel-native-local
```

The build command also builds Vite assets, emits the Spinel project, prepares
the compatibility layer, and compiles its executable at
`tmp/roundhouse/spinel-native-local/build/bin/blog`. Choose a fresh
`spinel-native-<name>` on subsequent builds: the driver refuses to overwrite
an existing generated tree. Stop an existing server before reusing its port.
Compilation uses `-O 0 --no-inline-hot` and one C compiler job.

Open <http://127.0.0.1:3901/imports> and sign in with the disposable account
`spinel@example.test` / `spinel-local-experiment`. The native app uses its own
SQLite database and signing secret inside the generated project. Its seeded
account is separate from Rails accounts. The server binds to loopback and
runs one process with two Spinel workers; stop it with Ctrl-C.

The native experiment sends direct sign-ins and dashboard return URLs to
`/imports`, because the dashboard still has the relation-support failure
listed above. This adjustment applies only to generated Spinel output;
the Rails app keeps its existing sign-in destination. Older generated
executables need a fresh build to pick up this change.

In another terminal, verify the server:

```sh
experiments/roundhouse/verify-native
# If using a different port:
experiments/roundhouse/verify-native http://127.0.0.1:3902
```

The verifier asserts the working login/health/asset/session paths, follows
the post-login redirect for both direct and dashboard-entry sign-in, and prints
the status of the other routes. Printed HTTP 500 probes are known gaps, not
passing functional checks.

For the original Rails app and its regression suite:

```sh
bin/rails db:setup
bin/dev                     # http://localhost:3000
# In another terminal:
bin/rails test
```

Rails development setup uses the environment settings described in the root
README, including `ADMIN_EMAIL` and `ADMIN_PASSWORD` for the seeded login.

## Compatibility gaps found

- **Roundhouse static inference:** route/controller naming, inferred hash key
  types, generic block accumulators, dynamic token readers, and colliding
  `Data` class names needed app changes. Generated RBS also needed corrections.
- **Rails and gem coverage:** Active Record relations, date operations,
  uploaded files, Active Storage, RubyLLM, deferred Inertia props, and engine
  routes remain incompletely modeled. The strict transpilation diagnostics
  and observed runtime failures are cataloged in [SPINEL.md](SPINEL.md).
- **Generated native runtime:** local adapters provide the tested sign-in,
  pagination/view helpers, Unicode normalization, and basic Inertia response
  paths. They do not implement the full Inertia protocol or all Rails behavior.
- **Spinel compiler:** four C code-generation defects required a saved compiler
  patch and focused native smoke checks. These are distinct from Roundhouse's
  transpilation gaps.
- **Rust target:** the initial output had missing runtime support and invalid
  Rust expressions. [RUST.md](RUST.md) retains those pre-change results.

Provider calls, classification, persistent background jobs, and Mission
Control have not been demonstrated in the native executable. The native PWA
service-worker route also fails. Full Rails tests passing does not prove
those native paths work.

## Files and evidence

`experiment` drives the pinned toolchains and builds. `prepare-spinel`,
`compile-spinel`, `compat/`, and `spinel-compiler.patch` contain the saved
native adjustments. `seed-native` and `verify-native` reproduce the isolated
login and HTTP checks. The two smoke programs exercise compiler and Unicode
behavior. [SPINEL.md](SPINEL.md) explains the source changes and toolchain pins.

Downloaded sources, caches, generated apps, databases, executables, logs,
and browser evidence stay under the ignored `tmp/roundhouse/` directory.
They are regenerated by these scripts rather than committed to this branch.
