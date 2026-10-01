# Experiment status — October 1, 2026

This is a checkpoint of the experimental branch, not a claim that the full app
has Rails parity. The native executable builds and runs, normal authentication
works, and the recorded fixture checks pass. Browser testing has also exposed an
unresolved transactions-page error. Keep the memory guard enabled.

## Current build and server

- Generated project: `tmp/roundhouse/spinel-native-v24` (ignored, reproducible).
- Dev server: <http://127.0.0.1:3901/>; ordinary admin sign-in with
  `spinel@example.test` / `spinel-local-experiment`.
- Separate experiment SQLite database; Rails development data is untouched.
- Roundhouse pin: `3219450199e45b23bb716acdb63edbea01fd2714`.
- Spinel pin: `65121d29b14d7095d5172f50f232ee839332aab6`.
- These are the upstream versions fetched and tested on October 1; they are
  pinned for reproduction, not a promise that upstream has stopped changing.
- Native runs use one process, two OS workers, full-mark GC
  (`SPINEL_GC_MINOR=0`) and a sampled 512 MiB process-tree ceiling.

[README.md](README.md) has setup, compilation, seeding, running and verification
commands. [SPINEL.md](SPINEL.md) describes the compatibility fixes and boundaries.
Generated binaries, databases and raw logs remain under ignored `tmp/roundhouse`;
the source, adapters, compiler patches and verification scripts are committed.

## Working in the recorded checks

| Area | Evidence and scope |
| --- | --- |
| Compilation/startup | Fresh v24 generation/preparation/native compilation succeeded. The later rebuild adding timing logs also succeeded: 77.6 seconds, 896.4 MiB peak process-tree RSS under the 1 GiB build guard. |
| Authentication | Normal password checks, signed sessions, CSRF/origin checks, requested return URLs and logout passed. Invitation registration, tenant/admin isolation, password-reset token invalidation and session revocation passed. No login bypass or Imports landing workaround. |
| Pages | All 13 Svelte navigation destinations rendered in Chromium on seeded data. HTTP checks also covered chat/import details, offline snapshot, PWA/assets and the native jobs monitor. This does not cover every filter or real imported dataset. |
| Writes | Fixture checks passed for search/filters, saved queries, transaction notes/categories/tags, bulk edits, budgets/cents, subcategories, settings/onboarding, model access/favorites and AI preferences. |
| Imports/classification | Fixture CSV upload, preview, queued classification, retained CSV download and commit passed. This is not exhaustive coverage of arbitrary statement data. |
| Jobs/chat/insights | Persisted classification/chat/insight jobs and no-key fallback paths passed; local insight evidence and snapshot output were checked. No-key chat jobs can finish with a handled assistant failure; their completion is not evidence of a real model response. |
| Configured AI protocols | Local stubs passed all nine combinations of budget/spending/search tools and OpenAI/Anthropic/Gemini, including callbacks, tool results, persisted messages and token accounting. Structured insight editing passed for all three protocols. |
| Live browser updates | Normal form sign-in, Inertia navigation, authenticated Cable subscription and a live completed chat response passed against the local provider stub. |
| Request console | HTTP status/method/path/duration logging was added and verified after restart, including actual 500 responses. The monotonic timing includes body consumption, dispatch and HTTP response writes; WebSocket entries measure upgrade dispatch separately. |

## Known broken or incomplete behavior

- **Transactions page:** browser testing produced repeated
  `500 GET /transactions -- TypeError: no implicit conversion of Date into Integer`,
  both before and after timing logging was added. Other transactions requests
  returned 200. The console records paths rather than query strings, so the exact
  failing filter/input is not captured there. The cause is unresolved and no
  regression test currently covers that observed failure. Fixture passes must
  not be interpreted as proof that transactions work with every date/filter/data
  combination. Recent log evidence is in `native-dev-server.log`.
- **Strict Roundhouse compilation:** still fails with 32 type errors and zero
  unsupported/syntax errors. The runnable build uses survey output and recorded
  adapters. Deferred props, relation APIs, nullable numeric/date values, RubyLLM
  metadata and mailer state remain among the inference gaps.
- **Framework parity:** Inertia deferred props are resolved eagerly; full partial
  reload/version/history semantics are not established. The native job monitor
  replaces Mission Control; Solid Queue recurring scheduling and concurrency
  semantics are not reproduced. Scheduled reminders need an explicit scheduler.
- **Email delivery:** invitation/reset/reminder messages are local JSON spool
  files. SMTP, production delivery, HTML layouts and attachments are not implemented.
- **AI parity:** native transport implements the app-used protocols, but complete
  RubyLLM discovery, retries, caching and streaming behavior are not established.
- **Storage/platforms:** local SQLite and retained CSV storage are covered, not
  the full Active Storage service matrix. Scripts target this macOS ARM/Homebrew
  environment; other platforms and production deployment are not verified.
- **Memory:** the original growth trigger was repaired and full marking avoids
  an observed generational-GC fault. Neither finding proves all leaks are gone
  or fixes the upstream GC implementation. The first final soak failed its
  growth assertion; the continuation on the same server passed (details below).

## Checks actually run

These results precede the final request-logging addition unless stated otherwise.
The logging rebuild was followed by normal admin sign-in and dashboard,
transactions, imports and spending HTTP checks, redirects/404s, and observation
of timed browser requests and failures. The full suites and long soak were not
rerun after that logging-only change. Committing this checkpoint does not erase
the failures found during subsequent browser testing.

| Check | Recorded result | Local log under `tmp/roundhouse/logs/` |
| --- | --- | --- |
| Rails Minitest, one worker | 209 tests, 1,080 assertions, zero failures/errors/skips | `rails-final-tests.log` |
| RuboCop on changed Ruby files | 39 files, no offenses | `rubocop-final.log` |
| Targeted Roundhouse regressions | 22 passed: form coercion, contextual keyword binding, parameter presence/attribute binding, nested permissions and collection-route ordering | `roundhouse-final-regressions.log` |
| Native page/prop checks | Passed | `verify-native-v24.log` |
| Native write/action checks | All 14 groups passed | `verify-actions-v24.log` |
| Native invitation/reset/isolation checks | Passed | `verify-account-v24.log` |
| Native stubbed AI + Chromium/Cable checks | Passed; no real provider calls | `verify-ai-v24.log` |
| Initial final memory soak | 1,040 navigation/snapshot reads and 260 completed no-key chat jobs; failed unchanged `<8 MiB` final-half growth assertion at +13.1 MiB; RSS reached about 190 MiB | `memory-final-soak.log` |
| Continuation on the same server/PID | Another 2,100 reads and 420 completed no-key chat jobs; passed unchanged assertion, plateau about 163 MiB, final-half growth +0.6 MiB | `memory-final-extended-soak.log` |
| Fresh full native build | Passed, 859.3 MiB compilation peak | `native-v24-build.log` |
| Later request-logging rebuild | Passed, 896.4 MiB compilation peak | `spinel-native-v24-build.log` |
| Strict compilation | Failed: 32 type errors | `spinel-strict-final.log` |

Additional checks during this experiment covered native compiler/Unicode smoke
programs, Gregorian date arithmetic/hydration, decimal rounding/formatting,
scoped record creation, captured-string GC, patch application to clean pinned
toolchains, and guard memory/deadline/interruption/descendant cleanup. They are
focused checks, not the complete upstream compiler/runtime test suites.

Before this checkpoint commit, syntax checks passed for eight Python experiment
scripts, the Bash driver, the browser JavaScript check and seven Ruby seed/adapter
files. Both saved compiler patches were verified against the patched pinned
checkouts. These checks do not replace functional execution.

The two memory stages together exercised 3,140 reads and 680 completed no-key
chat jobs on one server, plus additional polling requests. Finite plateau
evidence is not proof of leak freedom. The 200 ms guard sampling can overshoot
its threshold during an allocation burst.

## Not tested or not revalidated for this checkpoint

- Real OpenAI/Anthropic/Gemini requests, paid-provider behavior, network/TLS error
  handling, rate limits, retry/caching semantics and long streamed responses.
- Exhaustive imported CSV formats, large datasets/uploads, all date filters and
  the particular transaction failure observed during browser testing.
- A long memory soak of the final timing-enabled executable, prolonged user
  sessions, many concurrent connections or real-provider workloads.
- Full `bin/ci`, the complete Rails Playwright suite, bundler-audit and Brakeman
  for these experiment changes. The recorded Chromium check targets the native
  app and does not replace those suites.
- Complete Roundhouse/Spinel upstream test suites, full clean-machine setup,
  Linux/Windows builds, production deploy, SMTP or nonlocal storage backends.
- Rust compilation/runtime after the Spinel follow-up. [RUST.md](RUST.md) records
  the earlier failures; a working Rust app has not been demonstrated.

The next functional repair is the native transactions date/input error, followed
by a focused regression using the failing request/data and broader filter checks.
