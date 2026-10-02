# Roundhouse → native Spinel compatibility notes

## Purpose and tested snapshot

Transactions remains a Rails app with SQLite and its existing Svelte/Inertia
frontend. Roundhouse emits Ruby and sidecar types; Spinel compiles that output
to a native executable. The experiment aims to keep ordinary application code
and repair compiler/runtime behavior where it is shared.

The October 2 upstream refresh uses Roundhouse
`e74a81da1fa9d465f6d0daac12483c1e0837f4e5` and Spinel
`7ca803c957565e40436155edaab47cf1cdd4b960`, with the saved patches.
These identify the fetched snapshot; upstream may advance afterward. The fresh v8
native build passed all 13 navigation pages, all 15 action groups, account flows,
19 date-filter cases, Chromium navigation and configured-provider protocols
against local stubs. Its default-GC soak passed 2,100 reads and 420 completed
no-key chats. Authentication-heavy checks need server restarts between suites
to preserve the normal login rate limit. Strict compiler and gradual-type checks
remain failing.
[STATUS.md](STATUS.md) records execution results and limitations;
[README.md](README.md) contains complete commands. Old generated projects and
SQLite files remain under ignored `tmp/roundhouse` for comparison.

## Application workarounds removed

- Ordinary record arguments are restored in transaction, import, model,
  subcategory and saved-query path helpers. Ruby-family route boundaries use
  the existing `ActiveSupport.to_param` protocol, retaining scalar IDs and
  custom model slugs instead of coercing every argument to Integer.
- Array `compact_blank` and the normal `defined?` memoization check replace
  experiment-specific alternatives. Supported Hash key helpers retain their
  normal calls; opaque insight responses still use the existing explicit
  `transform_keys(&:to_sym).slice(...)` normalization.
- The app's Date shim and sidecar, Date-to-Time substitutions, generated Date
  constant substitutions and Date SQL/RBS post-processing are removed.
  Calendar dates are actual Date values in the compiler runtime.
- The native Time wrapper is removed; boxed Time formatting/accessors are
  handled by the patched Spinel compiler. Four Insights Array-return RBS
  downgrades are also removed rather than maintained as preparation changes.
- Duplicate authentication, LIKE sanitizer and truncation helpers are removed.
  Authentication uses the emitted normal app flow and real bcrypt; truncation
  and LIKE sanitizing use the shared runtime. The app's String truncation call
  is handled by shared lowering, without a generated-source replacement.
- Already-merged collection-route precedence, typed form coercion and literal
  scoped-creation repairs are used from upstream.
- External gem constants use ordinary `sig/` declarations for the app-used
  RubyLLM/Inertia APIs and bcrypt error type. Opaque gem results remain `untyped`;
  the declarations do not replace the native adapters or claim full gem typing.

Some earlier source changes remain because their underlying behavior is still
unsupported or because removing them would reintroduce observed growth: explicit
owner queries in affected association paths, explicit grouped SQL, consistent
pagination key types, a saved-query memoization assignment and explicit insight
result fields/cleanup and normalization of opaque insight data. The patch and
adapters remain substantial; this is not an unpatched Rails-compatible runtime.

## Shared repairs retained in the patch

| Area | Behavior retained or repaired |
| --- | --- |
| Dates and intervals | Native Date hydration/JSON/SQL, calendar arithmetic, hashing and Rational subtraction; DateRange lowering distinguishes Date intervals from Time intervals. Model owner metadata and exact helper return types survive lowering. |
| Inference | Integer `times.map`/`collect` binds integer offsets; integral duration constructors and implemented Date/Time conversions have grounded types. Parameter defaults are typed before model method bodies. |
| Relations | Relation demand survives `to_sql` and association/helper chains; generated association ID readers are registered using the same catalog as synthesis. Scoped creation retains supported equality attributes and setup blocks. Symbol-clause `unscope` and bounded primary-key `find_in_batches` support filtering and classification. |
| Authentication | Supported `authenticate_by` arguments bind once, normalized lookup and generated setters use the supported model normalization, empty passwords fail, and missing users retain bcrypt work. |
| Parameters and forms | Presence, nested array permissions, scalar permissions and raw JSON shape are preserved; malformed JSON gets a client error. Contextual keyword defaults retain the upstream forwarding metadata. |
| Collections and helpers | Pair destructuring is applied only with multiple block parameters; supported index/fetch/group operations retain their shapes. Recursive request Array/Hash narrowing preserves declared members while arbitrary untyped values retain gradual diagnostics. Typed String truncation uses the shared view helper, preserves argument order and returns a fresh mutable result. Literal-array compact_blank handles the app's defaults without overriding custom Array methods. LIKE escaping uses a shared exact scanner. |
| Constants | Blockless builtin `Data.define` factories with unique literal Symbol members and their aliases resolve through exact declaration owners. Custom factories, dynamic members and factory blocks retain their diagnostic boundaries. |
| Runtime block signatures | A runtime method's own RBS block contract survives return-only cross-file registry seeds; single Array block parameters receive the array as one argument, rather than losing element types. |
| Hash keys and tool arguments | Keyword-rest arguments are real Hashes with unknown members. Proven String/Symbol keys use typed shared helpers only when core conversion methods are intact; opaque or custom keys retain a generic result. Tool facade calls match emitted positional/keyword contracts instead of passing a keyword Hash into a Date parser. |
| Native Spinel C | Boxed Time formatting/accessors, safe String lending/iteration qualifiers, long Hash merge expressions and inline result coercion. BigDecimal formatting/rounding and CSV String/IO input remain patched. |

Tests that remove analyzer errors exercise emitted code as well as diagnostics.
Route tests cover untyped serializer/helper arguments, IDs, custom slugs,
nesting, optional segments, format/default keywords, HTML and Jbuilder. Date
checks cover actual emitted intervals and SQLite controls, plus native HTTP
filter checks recorded in STATUS. The entire upstream toolchain matrix has not
been run locally.

## Remaining runtime adapters

`prepare-spinel` still installs explicit native support for:

- Inertia rendering, built frontend assets, shared props, signed session state,
  CSRF/XSRF mapping and conditional preview routes.
- SQLite job state/arguments/errors, restart recovery and a native jobs monitor.
- Mail spooling and the app-used RubyLLM text/schema/tool protocol facade.
- Multipart uploads, retained CSV download, ICU Unicode and schema-aware
  aggregate casting, plus a few boxed pagination/AI sidecar boundaries.
- Nested Cable JSON messages and per-job broadcast cleanup.

These are framework adaptations. Deferred Inertia props are evaluated eagerly;
complete partial/deferred/version/history conformance is unverified. The jobs
monitor replaces Mission Control. Solid Queue scheduling, recurring tasks and
concurrency controls are not reproduced; scheduled reminders need an explicit
scheduler. Mail goes to `storage/mail/*.json`; SMTP, HTML layouts and attachments
are not implemented. Native signing secrets and reset tokens are independent
of Rails. Storage coverage is local SQLite/retained CSV, rather than arbitrary
Active Storage services or mounted Rails engines.

The AI facade covers the app-used OpenAI Responses, Anthropic Messages and
Gemini content requests, tools, JSON Schema and token accounting. Protocol tests
use local stubs and fake keys. Real paid providers, retries, caching, streaming,
provider discovery and network/TLS failure behavior remain unverified.
Opaque model responses can contain any JSON shape; app normalization remains
explicit rather than asserting a false Hash return type for parsed responses.

## Date and inference limits

Date supports the app's civil calendar operations for years 1–9999, the default
Italian reform, strict ISO parsing and the two app-used strptime patterns.
Formatting supports the implemented civil tokens; unsupported clock/week/era
formats raise instead of pretending full stdlib parity. Arbitrary Date calendar
starts, all Ruby Date formats and timezone-sensitive Date-to-datetime SQL
intervals are not established. Date interval SQL is restricted to a known Date
column owner. Other transpilation targets keep their existing Date diagnostic
boundaries.

Relation batching models the default ascending primary-key cursor and a positive
`batch_size`, retaining an outer limit and initial offset. Alternate cursor/order
options, blockless enumerators and complete Rails batching APIs are unverified.
`unscope` handles the implemented Symbol clauses; selective Hash removal is not
implemented. Relation cloning and creation defaults remain experimental, with
incomplete Range/OR/merge behavior. Grouped aggregates still use explicit SQL in
the app, and schema-aware aggregate Date hydration uses the native adapter.

Normalization support is the recognized model-local strip/downcase declaration
and its generated setters/authentication lookup. Arbitrary or inherited lambdas
and normalization of every general query are not claimed. Generated association
ID readers follow the existing Integer-key contract; UUID/custom-key parity is
not established. Strict analysis still reports real errors; survey generation
keeps those limitations visible rather than treating them as resolved.
The current scalar DTO presence policy treats raw JSON null as omitted. Explicit
nil passed through model Hash updates is covered, but that does not establish
Rails-equivalent null assignment through every request DTO.

String truncation supports a typed String receiver, Integer positional length
and optional literal `omission: String` option. Separator, dynamic option hashes
and attached blocks remain explicit gaps. Custom receivers and known String
reopens keep their own dispatch. Literal-array `compact_blank` retains custom
Array overrides; it does not turn an unknown receiver into an Array.

Generic Hash key conversion cannot promise String keys: a custom key's `to_s`
can return another type. Its shared helper retains `Hash[untyped, untyped]`;
the String/Symbol variants retain a String-key contract only for proven keys
with the core `to_s` methods intact. Emitted controls exercise custom keys,
method overrides, value preservation and a fresh result. The app's typed
transaction update uses the matching layout, but Spinel's general mutable
`Hash#merge!` across different native key layouts remains a reproduced gap.
Opaque insight JSON still uses the app's explicit normalization.

The model-catalog importer's `model_table_ready?` rescue still contains unsupported
`ActiveRecord::NoDatabaseError` and `ActiveRecord::StatementInvalid` constants.
The generated stubs and those database-failure paths remain unverified; legitimate
JSON/Errno exception declarations do not implement Active Record exceptions.

Runtime typing remains an upstream contribution blocker: Bar A passes with no
unresolved inference sites, while Bar B counts 562 `Ty::Untyped` sites against
the unchanged ceiling of 519. This is unresolved debt, not a passing gate.
The attempted full library-test compilation was stopped at 2,053.4 MiB by the
2 GiB guard; the full library/default suite has not passed. STATUS lists focused
passing targets alongside the failed and incomplete checks.

## Memory and reproducibility

Builds and servers always run under a whole-process-tree RSS guard. Defaults are
512 MiB for the server, 1,024 MiB for native compilation and 2,048 MiB for toolchain
builds. Compilation is serial; Cargo uses optimization 0 and 256 codegen units,
and native C compilation uses `-O 0 --no-inline-hot` without debug symbols.
The server uses one process and two OS workers.

The driver uses Spinel's upstream generational-GC default without forcing
`SPINEL_GC_MINOR`. The final v8 soak passed 2,100 reads and 420 completed no-key
chats, plus polls, with RSS samples of 101.8–116.0 MiB and 3.4 MiB final-half
growth against the unchanged `<8 MiB` assertion. `SPINEL_GC_MINOR=0` remains an
explicit full-marking comparison. Earlier v5 comparisons and their logs are
labeled historical in STATUS.

These finite samples do not establish that every input, large upload, concurrent
connection or provider workload is leak-free, or that every remembered/pinned-cell
fault seen earlier is repaired. The guard samples every 200 ms and can overshoot
during allocation spikes; keep it enabled.

Updating either compiler means fetching its default branch, rebasing the saved
patch onto a separate checkout, rebuilding under the guard, rerunning native
checks and recording the tested SHA. Both patches are checked forward against
clean pinned sources and in reverse against patched checkouts. Scripts assume
this macOS ARM/Homebrew ICU environment. Other operating systems, production
deployment, full clean-machine setup and the Rust target were not revalidated.
[RUST.md](RUST.md) preserves the original Rust evidence.
