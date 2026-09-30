# Roundhouse Rust experiment

These are the initial Rust results, before the app compatibility changes on
this branch. Rust was not rerun after those changes. See the
[experiment overview](README.md) and [Spinel results](SPINEL.md) for the later
native build.

Tested September 30, 2026 against Transactions revision `be77d90` with no
changes to the Rails app. **The complete app does not currently compile to a
runnable Rust executable with Roundhouse.**

## Results

| Attempt | Result |
| --- | --- |
| Current-source compiler, `3f5753ad` | Compiler built successfully with Rust 1.97.1. |
| Strict Rust transpilation | Exit 1: 8 unsupported errors and 118 type/lowering errors. |
| Survey Rust transpilation | Exit 0: emitted 160 files, with unsupported behavior and placeholders. |
| Build of survey output | Exit 101: 1,243 Rust compiler errors and 439 warnings. No executable produced. |
| Official release, `v2026.9.18`, `2e286e6f` | Downloaded macOS ARM binary; archive SHA-256 matched the published checksum. |
| Release strict transpilation | Exit 1: JSON fixture `grocery.raw_data` is not a scalar. |
| Release survey transpilation | Exit 0: emitted 156 files, with four ingest gaps. |
| Build of release survey output | Exit 101: 1,244 Rust compiler errors and 430 warnings. No executable produced. |

The current compiler's separate analysis reports 32 errors, 480 warnings,
31 gap-attributed notes, three ingest gaps, and five unknown gems:
`inertia_rails`, `pagy`, `resend`, `ruby_llm`, and `schematist`.
These diagnostics include Roundhouse coverage limits; they do not establish
defects in the working Rails application.

## Concrete blockers

- Inertia rendering, deferred props, shared props, and Vite layout helpers
  have no usable Rust implementation. The emitted sign-in controller calls
  `render` with a nested hash, while its generated `render` accepts a string.
- Dynamic Active Record relations remain in controllers and services; the
  Rust target has no runtime `Relation` to execute them.
- Ruby keyword arguments, JSON attributes, controller inheritance, and
  namespaced controllers produce type errors or unresolved runtime symbols.
- Some expressions produce invalid Rust outright: unary minus becomes
  `amount_cents().-@()`, append becomes `series.<<(...)`, regex arguments
  become comment placeholders, and an admin route references
  `admin::::ai_controls_controller`.
- The analyzer does not model the AI and pagination gems. Survey mode also
  drops routes, including external engine mounts.

Patching a handful of generated lines would not address these gaps. Running
this complete app requires substantial Roundhouse support for this stack or
an explicit application port. The generated trees were left unmodified.

## Reproduce

All compiler sources, downloaded dependencies, generated output, build
artifacts, and full logs are under the already ignored `tmp/roundhouse/`.
No existing database or environment file was copied into the experiment.
No Rails server, provider request, or deployment was started.

The driver pins the source compiler to the revision tested above. It uses
the installed Rust 1.97.1 toolchain by default; override with
`RUST_TOOLCHAIN=<installed-toolchain>` if needed.

```sh
experiments/roundhouse/experiment setup
experiments/roundhouse/experiment check
experiments/roundhouse/experiment strict

# If tmp/roundhouse/rust already exists, move it aside before regenerating.
experiments/roundhouse/experiment survey
experiments/roundhouse/experiment build

# Only available after a successful build; loopback port 3900,
# with a separate database under tmp/roundhouse/rust/storage/:
experiments/roundhouse/experiment run
```

`check`, `strict`, and `build` are expected to fail with this app and this
compiler revision. They save full diagnostics and exit codes in
`tmp/roundhouse/logs/`. `survey` succeeds but its output is incomplete.
`setup` and an uncached `build` need network access.

Original release comparison commands:

```sh
tmp/roundhouse/roundhouse-aarch64-apple-darwin/roundhouse --version
tmp/roundhouse/roundhouse-aarch64-apple-darwin/roundhouse \
  --target rust --survey --allow-unsupported \
  -o tmp/roundhouse/release-rust .
CARGO_HOME="$PWD/tmp/roundhouse/cargo-home" \
  CARGO_TARGET_DIR="$PWD/tmp/roundhouse/rust/target" \
  cargo +1.97.1 build --offline --release \
  --manifest-path tmp/roundhouse/release-rust/Cargo.toml
```

Original logs: `check.log`, `strict.log`, `survey.log`, `build.log`,
`release-strict.log`, `release-survey.log`, and `release-build.log`.

Roundhouse's [transpilation guide](https://github.com/rubys/roundhouse/blob/main/docs/guide/transpile.md)
explicitly describes survey output as incomplete and unsuitable for deployment.
