# Experiment status — October 2, 2026

The fresh v8 native Spinel build passes normal sign-in, all 13 navigation pages,
all 15 action groups, account flows, Chromium navigation and configured AI
protocol checks against local stubs. Its default-GC soak also passes 2,100 reads
and 420 completed no-key chats. These are recorded fixture checks with the saved
compiler patches and framework adapters. Strict compilation and the shared
runtime gradual-type gate remain failing; full Rails parity is not established.

## Reproducible snapshot

- Roundhouse: `e74a81da1fa9d465f6d0daac12483c1e0837f4e5`, plus `roundhouse.patch`.
- Spinel: `7ca803c957565e40436155edaab47cf1cdd4b960`, plus `spinel-compiler.patch`.
- These are the latest upstream revisions fetched for this October 2 run;
  upstream can advance afterward. The pins make this checkpoint reproducible.
- Recorded native project: `tmp/roundhouse/spinel-native-current-20261002-v8`.
  Generate fresh output under a new name to preserve earlier databases.
- Fixture login: `spinel@example.test` / `spinel-local-experiment`. It uses
  password verification, signed sessions and the ordinary dashboard destination.
  There is no login bypass or Imports landing workaround.
- The native SQLite database and signing secret are separate from Rails
  development data. Generate `config/schema.rb` before running `seed-native`.

[README.md](README.md) contains setup, compile, seed, run and verification
commands. [SPINEL.md](SPINEL.md) records repairs and compatibility boundaries.
Generated projects, binaries, databases and logs are ignored under
`tmp/roundhouse`; reproduction scripts, patches and adapters are tracked.

## Final v8 checks

Log paths below are relative to `tmp/roundhouse/logs/`.

| Check | Result and scope | Log |
| --- | --- | --- |
| Fresh native build | Passed; 88.1s, 840.0 MiB peak process-tree RSS. | `spinel-native-current-20261002-v8-build.log` |
| Native pages | Passed: normal session, 13 Inertia navigation destinations, chat index, offline snapshot, PWA/assets and native jobs monitor. | `current-20261002-v8-verify-native.log` |
| Native actions and date filters | All 15 groups and 19 date-bound cases passed, including transaction edits, budgets, saved filters, settings, CSV preview/classification/download/commit, background jobs, no-key chat/insights and logout. | `current-20261002-v8-verify-actions.log` |
| Native accounts | Passed: invitation/registration, one-time code, tenant/admin isolation, password reset, token invalidation, session revocation and new-password login. | `current-20261002-v8-verify-account.log` |
| Chromium navigation | All 13 pages passed; 822.0 MiB peak, 1.8s. | `current-20261002-v8-verify-browser.log` |
| Configured AI stubs | All nine budget/spending/search tool combinations across OpenAI/Anthropic/Gemini, three structured-insight protocols and live authenticated browser/Cable chat passed; 25 local stub requests. Chromium peak 921.6 MiB, 2.1s. No paid provider requests. | `current-20261002-v8-verify-ai.log` |
| Default-GC memory soak | Passed: 2,100 reads and 420 completed no-key chats, plus polls; RSS samples 101.8–116.0 MiB, final-half growth 3.4 MiB against the unchanged `<8 MiB` assertion. | `current-20261002-v8-default-gc-memory.log` |
| Focused Roundhouse gates | 16 targets, 67 tests: 66 passed, one failed, zero ignored. Peak 1,868.0 MiB, 63.8s. The sole failure is runtime Bar B; this command did not exit successfully. | `current-20261002-v8-final-affected-gates.log` |
| Runtime typing | Bar A passed with no unresolved runtime inference sites. Bar B failed: 562 `Ty::Untyped` sites against the unchanged ceiling of 519. | `current-20261002-v8-final-affected-gates.log` |
| App analysis and strict emission | Check: zero parse errors, 15 errors, 333 warnings, 28 gap-attributed notes and three survey gaps. Strict Spinel emission: 22 type errors, zero unsupported/syntax errors. Runnable output uses survey generation and recorded adapters. | `current-20261002-v8-check.log`, `current-20261002-v8-spinel-strict.log` |
| Rails Minitest | 209 tests, 1,080 assertions, zero failures/errors/skips; one worker. This preceded the last shared compiler fixes. Final insight-generator rerun: two tests, 12 assertions, zero failures/errors/skips. | `current-20261002-rails-tests.log`, `current-20261002-final-insight-rails-test.log` |
| Changed Ruby lint | Eight files, no offenses. Python/Bash/browser-JS syntax, native gem RBS and seed syntax checks also passed. | `current-20261002-final-rubocop.log` |
| Full Roundhouse library suite | Not completed: compilation was stopped by the 2 GiB guard at 2,053.4 MiB. No library/default-suite pass is claimed. | `current-20261002-latest-roundhouse-gates.log` |

Native compiler/Unicode and Date contract smokes also passed against the patched
pinned toolchains (`current-20261002-spinel-final-smokes.log` and
`current-20261002-date-smoke.log`). The focused tests include emitted execution
for Date/SQLite/partial updates, Data factories, containers, runtime blocks,
bounded batches, truncation, compact_blank, paths, calendars and keyword-rest
Hash helpers. Both patches passed clean forward and reverse application checks.

The date-filter checks cover open/inclusive/same-day bounds, invalid/empty/
whitespace inputs and every app quick range. They no longer reproduce the
previous Date-to-Integer error. Authentication-heavy verifiers require server
restarts between suites to preserve the legitimate ten-sign-ins-per-three-minutes
limit; the README documents this setup requirement.
The final dev-server page check also passed after writes. Dashboard totals are
checked against the live SQLite records rather than fixed pre-import counts
(`current-20261002-v8-final-server-health.log`).

## Repairs and removed workarounds

The app-specific Date implementation and RBS file, Date-to-Time substitutions,
Date SQL/RBS post-processing, native Time wrapper, String truncation source
replacement and four Insights Array-return RBS downgrades are removed. Date and
DateRange support lives in the compiler/runtime. Spinel handles boxed Time
operations through the C compiler repair. Normal record arguments, collection
helpers and password authentication remain in app code.

The Roundhouse patch contains bounded Data factory support, accurate runtime RBS
block binding, recursive container narrowing, Relation demand for bounded
batches, parameter/normalization support and route/helper repairs. Keyword-rest
arguments have a truthful Hash shape; specialized String/Symbol key helpers are
used only for proven key types with the core conversion methods intact. Opaque
keys and results retain gradual types and their actual semantics.

Ordinary `sig/` declarations describe app-used external gem APIs while opaque
results remain `untyped`. The baseline explicit normalization of opaque insight
JSON remains. These declarations do not implement Inertia or RubyLLM, and the
native framework adapters and compiler patches are still substantial.

## Remaining gaps and verification limits

- **Compiler checks remain failing.** Survey output does not resolve the 15
  analysis errors, 22 strict-emission errors or runtime Bar B debt. The full
  library/default upstream suite has not completed under the guard.
- **Framework parity is partial.** Inertia deferred props run eagerly; complete
  partial/deferred/version/history behavior is unverified. The native jobs
  monitor replaces Mission Control. Solid Queue recurring scheduling and
  concurrency semantics are not reproduced; reminders need a scheduler.
- **Mail and storage are local.** Messages are JSON spool files without SMTP,
  production delivery, HTML layouts or attachments. Storage coverage is SQLite
  and retained CSV, rather than all Active Storage services or Rails engines.
- **AI checks use local stubs.** No real paid providers, discovery, retries,
  caching, long streaming responses or network/TLS failures are claimed.
- **Date, relation and native Hash support remain bounded.** See SPINEL for
  calendar/formatter, interval-owner, batching, scoped-default and key-layout
  limits. Passing fixtures do not cover every input or custom schema/key type.
- **Error-path constants remain incomplete.** `ActiveRecord::NoDatabaseError`
  and `ActiveRecord::StatementInvalid` in the model-catalog importer's
  `model_table_ready?` rescue clause still emit unsupported-constant stubs.
  Those database-failure paths are not verified.
- **Other checks remain unvalidated.** No full `bin/ci`, complete Rails/native
  browser suite, security audit, clean-machine setup, non-macOS build or
  production deploy is claimed. Rust was not rerun;
  [RUST.md](RUST.md) retains its original evidence.

## Memory limits

The driver now uses Spinel's upstream generational-GC default without forcing
`SPINEL_GC_MINOR`. The final v8 workload passed with the unchanged growth limit;
this finite sample does not prove all inputs, concurrent sessions, uploads or
real-provider operations leak-free. `SPINEL_GC_MINOR=0` remains available for an
explicit full-marking comparison.

Historical v5 comparisons passed the same read/job counts: full marking sampled
146.3–176.6 MiB with 2.0 MiB final-half growth, and generational GC sampled
95.6–121.4 MiB with 0.5 MiB growth (`current-20261002-v5-full-gc-memory-rerun.log`
and `current-20261002-v5-minor-gc-memory.log`). These are earlier-build evidence,
not matched performance claims about v8 or proof that every GC defect is fixed.

Whole-process-tree guards remain enabled: 2 GiB for toolchain builds, 1 GiB for
native compilation and 512 MiB for the server. Sampling every 200 ms can overshoot
during an allocation burst; retain headroom and keep the guard enabled.
