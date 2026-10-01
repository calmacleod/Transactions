# Roundhouse → native Spinel compatibility notes

## Scope and evidence

This experiment compiles the Rails source into a native macOS ARM executable,
reuses the built Vite/Svelte frontend, and stores data in a separate SQLite file.
Normal sign-in reaches the dashboard and preserves requested return URLs.
Invitations and password resets use the app's ordinary credential checks;
there are no seeded-user authentication shortcuts.

This is an incomplete experiment. Subsequent browser testing exposed repeated
`/transactions` 500s (`no implicit conversion of Date into Integer`) alongside
successful requests; that input/date bug is unresolved. [STATUS.md](STATUS.md)
separates the passed fixture checks from observed failures and untested behavior.

The October 1 follow-up verifies authenticated page props and writes against
seeded, isolated data rather than treating a successful build as app parity.
`verify-native`, `verify-actions`, `verify-account`, `verify-browser.mjs`,
`verify-ai` and `verify-memory`
are executable assertions. Logs are under `tmp/roundhouse/logs`.

The Rails suite passed 209 tests and 1,080 assertions. Focused Roundhouse tests
cover form coercion, parameter presence, attribute binding, contextual keyword
defaults, nested row permissions and collection-route order. Native smoke programs
cover C code generation, Unicode, Gregorian dates, decimal rounding and scoped
relation creation. Real provider requests have not been tested; provider protocol
checks use local responses and fake keys.

The final browser check covers normal form sign-in, Inertia navigation and all
13 Svelte navigation pages. Local provider checks cover all nine combinations
of budget/spending/search tools and OpenAI/Anthropic/Gemini protocols, three
structured insight-editing responses, token accounting and authenticated live
WebSocket delivery. These checks do not contact paid providers.

## Fixes recorded

| Area | Failure found | Recorded change |
| --- | --- | --- |
| Relations | Owner associations emitted as Arrays, losing `where`, `includes`, ordering and aggregate behavior | Explicit scoped model queries in affected app paths; shared relation/scope lowering and RBS corrections |
| Creation | Scoped `find_or_create_by!` lost ownership and did not yield the setup block before validation | Preserve scalar equality scope attributes and run the block before saving; do not yield an existing record |
| Forms | Text/JSON form values reached numeric and Boolean setters with the wrong native representation | Cast typed DTO values at assignment; preserve omitted fields and array-valued permissions |
| Nested CSV rows | `permit` remained on plain emitted hashes | Filter residual scalar permissions after flat DTO synthesis, retaining strong-parameter filtering |
| Keyword arguments | Optional keywords became positional values; later keywords bound to earlier slots, sometimes as Hashes | Preserve contextual defaults and instance keyword binding; normalize literal class/helper keywords consistently |
| Routes | `/transactions/bulk_update` matched the standard `/:id` update route | Emit collection/custom routes before dynamic resource members |
| Dates | Missing Date values, hydration, month arithmetic, hashing and range handling | Gregorian date adapter and DateRange; preserve dates in SQLite/JSON and distinguish boxed Date/Time values |
| Money | Decimal conversion, fixed formatting and rounding were incomplete | Shared decimal lowering and Spinel BigDecimal fixes; verify half-up cents and negative/decimal cases |
| Imports | Uploaded-file/IO modeling, attachment download and filename headers were incomplete | Native multipart IO support, retained-file download and `Content-Disposition` |
| Data classes | Bodies of `Data.define` declarations and colliding result names were mishandled | Preserve declaration methods and use distinct result class names |
| Hashes | Mixed String/Symbol pagination keys caused rapid request-memory growth | Normalize filter keys before merging; maintain consistent key types at API boundaries |
| Insight candidates | An implicit empty branch retained a nested result in compiled code | Explicitly skip a category that yields no meaningful finding |
| Analysis shape | `summary.merge` retained the original Hash-only inferred value type, passing a findings Array using the wrong native representation | Return explicit analysis fields and make the LLM findings array boundary explicit; verify structured insight editing |
| Authentication | Generated session state lost Boolean values; browser XSRF header was not copied to the request verifier | Signed JSON session envelope and standard Inertia XSRF-header mapping; keep password checks, CSRF and authentication filters |
| Browser cookies | Unsigned cookie jar serialized the options Hash instead of its value | Set the XSRF cookie to the actual token using the native jar's value API |
| Live updates | Action Cable's native payload encoder only supported integer values | Encode nested chat/import messages as JSON; verify an authenticated subscription and live completed chat response |
| AI integration | RubyLLM runtime/schema/tool declaration APIs were absent | Export declaration metadata using the installed gems; native transport for app-used text/schema/tool flows, finite timeouts and tool rounds |
| Jobs/mail | In-memory placeholders lost work or retained deliveries; the persistent job thread retained its broadcast log | SQLite job state/arguments/errors, disk mail spool and per-job log cleanup; interrupted jobs requeue on restart |
| Spinel C | Hash merge expression truncation, rescue String lending, Time boxing, result-type coercion and String iteration casts | Saved `spinel-compiler.patch` and native compiler/Unicode/decimal checks |

The source changes favor explicit scopes, IDs, accumulators and scalar conversions.
They preserve the Rails behavior exercised by its suite. Framework-specific
adapters remain in the experiment and generated output.

## Memory findings

The original unbounded run could grow rapidly while assembling transaction
pagination URLs. Mixed key types were one reproduced trigger. The repaired
runtime also encountered an invalid generational remembered/pinned-cell scan,
so the driver uses full marking (`SPINEL_GC_MINOR=0`) while retaining GC.
This is a stability setting, not a claim that the upstream GC defect is fixed.

`guard` counts the child process tree, including children that change process
groups. It samples every 200 ms, enforces a memory ceiling and optional deadline,
reports peak RSS, and terminates owned descendants. Ctrl-C has a two-second
shutdown grace period. Intentional allocation beyond a 64 MiB test ceiling
was terminated without leaving the allocator running. Sampling can overshoot
the threshold during a rapid allocation burst.

| Operation | Default ceiling / configuration |
| --- | --- |
| Native server | 512 MiB; one process, two OS workers |
| Native compilation | 1,024 MiB; `-O 0 --no-inline-hot`, one C worker, no debug symbols |
| Toolchain build | 2,048 MiB; Cargo/make serial; Cargo release optimization level 1 |
| Long memory check | Two stages on one server: 3,140 authenticated navigation/snapshot reads and 680 completed no-key background chat jobs, plus polling requests |

The first final soak rose from 174.4 to 189.7 MiB and failed the unchanged
final-half growth assertion (+13.1 MiB). Extending the same server with another
2,100 reads and 420 jobs passed that assertion: RSS settled near 163 MiB, with
final-half growth of 0.6 MiB. The full guarded run peaked at 192.2 MiB. The
request-logging addition was compiled and checked over HTTP afterward, but the
long soak was not repeated on that executable. Successful compilation peaks
remained below 1 GiB. A finite soak cannot cover every input,
provider response, upload size or combination of actions. Keep the guard enabled.

## Remaining compatibility boundaries

- **Strict inference:** strict emission still fails. The current ledger includes
  32 type errors, including Inertia deferred props, relation IDs/`to_sql`, nullable numeric/date behavior,
  RubyLLM metadata, sanitizer resolution and mailer view state. The executable
  uses survey output and the recorded adapters; strict diagnostics are not hidden.
- **Inertia:** native rendering resolves lazy/deferred props eagerly and supplies
  normal pages, assets, cookies and JSON. Full partial/deferred/version negotiation
  and history behavior do not have complete Rails conformance coverage.
- **Jobs:** native SQLite queueing covers the app's six job classes and job errors,
  retries/deletion and restart recovery. The jobs page is a native monitor rather
  than Mission Control. Solid Queue scheduling/concurrency/recurring-task semantics
  are not reproduced, so scheduled CSV reminders need an explicit scheduler.
- **Mail:** invitations, reset links and reminder messages are written to JSON
  files locally. SMTP, HTML layout/inline attachments and production delivery are
  not implemented. Reset tokens use the isolated app's signing secret and are
  invalidated when the password changes; Rails and native tokens are separate.
- **AI:** the native facade covers the app-used OpenAI Responses, Anthropic
  Messages and Gemini content protocols, tool results, JSON Schema and token
  accounting. Live provider behavior, provider-specific error/retry/caching and
  streaming parity remain unverified. Model refresh uses RubyLLM's published
  catalog rather than its complete provider discovery pipeline.
- **Uploads/frameworks:** this is the app's local SQLite/retained-CSV storage path,
  not a complete Active Storage service matrix or arbitrary Rails engine support.
- **Portability:** scripts assume this Mac's ICU/Homebrew layout. Linux/Windows
  builds and production deployment are outside the recorded checks.

## Reproduction and version policy

[README.md](README.md) contains the complete compile, seed, run and verification
commands. Toolchains were refreshed from upstream on October 1 and then pinned:
Roundhouse `3219450199e45b23bb716acdb63edbea01fd2714`, Spinel
`65121d29b14d7095d5172f50f232ee839332aab6`. Patches apply to those revisions.
The commit IDs identify the tested snapshot; upstream can advance afterward.

Updating a toolchain means fetching its current default branch, preserving and
rebasing the saved patch, rebuilding under the guard, rerunning the native checks
and recording a new pin. Do not silently pull moving dependencies during startup.
The initial Rust survey failures remain in [RUST.md](RUST.md).
