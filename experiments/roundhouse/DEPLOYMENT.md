# Experimental Spinel deployment

The experimental service uses `config/deploy.spinel.yml` as a separate Kamal
config (`-c config/deploy.spinel.yml`), rather than a destination overlay on the production Rails service.
Its service/image are `transactions-spinel`, its hostname is
`transaction-spinel.callummacleod.ca`, and its SQLite/storage volume is
`transactions_spinel_storage`. Production remains `transactions` on
`transactions_storage`.

The config reads the existing production server, registry, secret names and
clear environment variables. It reuses `.kamal/secrets` and its Bitwarden
adapter. Its separate hook directory excludes the production Rails port-3000
warm-up hook; Kamal probes the native health endpoint on port 3901.
Application origin variables point to the experimental hostname;
`BLOG_DB`, `PORT`, `WORKERS`, `SPINEL_WORKERS`, `NATIVE_BIND_HOST` and
`NATIVE_APP_URL` configure the native process. The bind host is `0.0.0.0` inside the container; ordinary
local runs retain the default `127.0.0.1`. Passing the Rails/provider secrets does not implement
Rails encrypted credentials, New Relic or SMTP in the native runtime.

## Build

Run the local compiler setup in [README.md](README.md) first. With the pinned
patched compiler checkouts available, export the same `BWS_ACCESS_TOKEN` used
for production deploys. Keep its value out of shell logs. The configuration
and snapshot helper also require these existing public connection settings:

```sh
export KAMAL_SERVER_IP=144.217.240.192
export KAMAL_APP_HOST=transaction.callummacleod.ca
```

Prepare a fresh context:

```sh
export RUST_MIN_STACK=33554432
# Use a fresh project name and context for each build; keep prior output.
export SPINEL_BUILD_CONTEXT=tmp/roundhouse/deploy-context-next
experiments/roundhouse/package-image spinel-native-linux-deploy
native_version="$(git rev-parse HEAD)-spinel-$(date -u +%Y%m%d%H%M%S)"
```

Packaging emits and prepares a fresh project, then runs the pinned Spinel's
supported `spin pack` command locally under the 1 GiB guard. The portable bundle
contains generated C, runtime source, dependency C and its Makefile. The
curated context also carries frontend assets and the public merchant catalog.
Local databases, environment files and signing secrets are excluded.

The Dockerfile builds that C bundle on the server's native amd64 CPU with Clang,
`-O0 -g0`, one compiler worker and the unchanged 1 GiB/600-second guard. Forced
hot inlining is disabled during export. The pack's required ABI defines, include
paths and link inputs are preserved; the macOS ICU include directory is removed
because Linux uses `libicu-dev`. No macOS executable or object is copied into
Linux. This is Spinel's upstream portable-C packaging interface.

A dedicated Docker Buildx builder caps the whole build at 2 GiB and two CPUs.
Kamal forwards the existing local registry while building and pulling. The
default Docker context and other app builders are unchanged.

Create the dedicated builder once before the first build:

```sh
remote="ssh://root@$KAMAL_SERVER_IP"
builder="kamal-remote-$(printf '%s' "$remote" | sed 's/[^a-z0-9_-]/-/g')-local-registry"
context="$builder-context"
docker context create "$context" --description "$builder host" --docker "host=$remote"
docker buildx create --name "$builder" --driver docker-container \
  --driver-opt network=host --driver-opt memory=2g --driver-opt memory-swap=2g \
  --driver-opt cpu-period=100000 --driver-opt cpu-quota=200000 "$context"
```

With the capped builder available, publish the image:

```sh
bin/kamal build push -c config/deploy.spinel.yml --version="$native_version"
```

After building, `docker buildx stop "$builder"` frees its running resources
while retaining its cache. For later builds, reuse this builder. The names match
Kamal's remote-builder
selection and preserve the resource limits. Docker documents these driver
options in its [container builder reference](https://docs.docker.com/build/builders/drivers/docker-container/).

The container also has a 512 MiB Docker memory limit with no extra swap, and
the process guard stops growth at 480 MiB to leave room for its supervisor.
The experimental service sets Spinel's supported `SPINEL_GC_MINOR=0` full-marking
mode after the default generational collector failed the larger cloned-data
read-soak growth check. The same growth threshold is retained for validation.

## Clone and boot

Before the first boot, make an online SQLite backup of the live primary
`/rails/storage/production.sqlite3` using SQLite's backup API. A raw file copy
can omit committed WAL transactions. Record the production container revision,
snapshot time, integrity result and counts. Retain that backup under
`/root/transactions-backups/`
and put a separate copy in `transactions_spinel_storage`.

Copy retained storage files into the new volume too. Do not mount production
storage writable in the experimental app. Rails queue/cache/cable databases
are not inputs to the native job runner; existing production jobs must not
be replayed in the experiment. The native job tables start on its own clone.
All four Rails databases are backed up independently; there is no cross-database
atomic-snapshot claim. Their committed data is retained, but the native runner
does not execute the copied Solid Queue database's jobs.

The first clone is performed with:

```sh
experiments/roundhouse/clone-production-storage
```

This command refuses an existing experimental volume. It retains a complete
snapshot and manifest under `/root/transactions-backups/` on the server, checks
each database's integrity, and copies every snapshot-referenced attachment.
It maps the original Rails blob layout into the native adapter's `storage/files`
root within the clone. Files and signing secrets never enter the Docker image.

Do not run the disposable `seed-native --fixtures` command against the clone.
Use the accounts/passwords copied from production. The native runtime issues
its own session cookies and signing secret.

After the image and database clone have been prepared:

```sh
bin/kamal deploy -c config/deploy.spinel.yml --skip-push --version="$native_version"
bin/kamal app details -c config/deploy.spinel.yml
bin/kamal app logs -c config/deploy.spinel.yml
experiments/roundhouse/verify-deployment --browser --soak
```

Verify the deployed image revision and `native-build.json`, HTTPS `/up` and
`/session/new`, normal sign-in, read-only navigation and the clone's record
counts. Provider credentials are real on this deployment; the local stub
tests in STATUS do not establish paid-provider or production-mail parity.

## Rollback

For the first experimental deployment, stopping only its app removes it from
traffic while preserving its image and cloned volume:

```sh
bin/kamal app stop -c config/deploy.spinel.yml
```

For a later experimental release, use the recorded prior experimental version:

```sh
bin/kamal rollback <previous-experimental-version> -c config/deploy.spinel.yml
```

Do not run production rollback or volume-removal commands to undo this
experiment. Production's running container, storage and hostname remain
independent of the experimental service.

## Deployment evidence

The online snapshot completed at `2026-10-02T18:52:34Z` from production image
`be77d903af5506bb9fa8241b26ce19272f93c0a2`. Its retained backup is
`/root/transactions-backups/spinel-20261002T185233Z`. All four SQLite integrity
checks passed; the isolated volume contains 3,010 transactions, two users,
26 categories, nine subcategories, 16 imports, 601 import rows, six insights,
2,282 model records and all 15 retained blob files. Production kept running.

The first emulated amd64 app build exceeded its unchanged 1 GiB RSS guard
(1,031.5 MiB). A native amd64 attempt using a GCC `-O1` toolchain instead hit
the 600-second deadline during analysis (248.7 MiB peak). A native Clang `-O2` toolchain build passed
(365.1 MiB, 390.2s), but its app
compile also hit the unchanged 600-second deadline (542.4 MiB peak). These
failed image builds stopped cleanly and published no app image.

The supported local C export passed: 82.1s and 314.6 MiB peak. Native Linux
compilation of that export passed: 32.8s and 661.1 MiB peak, within the unchanged
1 GiB guard. The image was published as
`localhost:5555/transactions-spinel:bcf13edc3adabb4250db18226cce9a5e14a09816-spinel-20261002`
before a proxy health check found the native adapter's hardcoded loopback bind.
That container received no public traffic. `NATIVE_BIND_HOST` now defaults to
loopback locally and is `0.0.0.0` in the separate Kamal config.

The corrected export passed in 75.9s at 286.4 MiB; its native Linux compilation
passed in 33.2s at 663.6 MiB. The corrected image is
`localhost:5555/transactions-spinel:bcf13edc3adabb4250db18226cce9a5e14a09816-spinel-20261002-r2`,
registry digest
`sha256:1fef5d1fbd9a0d0859ce3cec043ae6e6b68e8145b0150dbb446e64bc436fcf83`.
The embedded `native-build.json` records application revision `bcf13ed`, the
pinned compiler/patch revisions, native-adapter SHA256s, packaging strategy and
generated C SHA256.
The corrected service deployed successfully. HTTPS `/up` and `/session/new`,
normal sign-in with the copied production admin account, all 13 authenticated
Inertia pages, all 15 retained CSV downloads, PWA/offline endpoints and the
native jobs monitor passed. Chromium rendered all 13 pages without runtime or
HTTP 500 errors (8.8s, 758.0 MiB browser-process peak in the final full-marking run).

The live container is an amd64 ELF executable with no unresolved shared
libraries, an independent storage mount, a 512 MiB cgroup cap and zero
restarts/OOM kills. All seven deployed secret values match the still-running
production container. Clone integrity and all original non-session record
counts remain unchanged after navigation. The first 2,100-read default-GC soak
completed without request errors or restarts, but failed the unchanged
`<8 MiB` final-half growth check: 27.8 MiB
(129.5–222.1 MiB sampled RSS). This is a failed check, not a leak-free result.

The same 2,100 authenticated reads passed with `SPINEL_GC_MINOR=0`, without
changing the growth threshold. Sampled native RSS was 145.9–376.0 MiB and ended
at 165.4 MiB; final-half growth was −206.2 MiB. The native process stayed alive
throughout; full marking reclaimed the accumulated heap around request 2,000.
The final run also passed normal account sign-in, all 13 browser pages and all
15 CSV downloads. This finite read workload does not establish that concurrent
sessions, uploads or provider jobs are leak-free. Keep the 512 MiB container
cap and 480 MiB process guard. Paid-provider jobs and production email delivery
are untested; native mail currently uses a JSON spool.

The image's application revision remains the `bcf13ed` source checkpoint plus
the native-adapter hashes recorded in `native-build.json`. Subsequent commits
of deployment configuration and documentation do not change that image's
recorded application provenance.

[STATUS.md](STATUS.md) describes the earlier macOS fixture verification and
remaining compatibility limits; those are separate from remote results.

Reproduction logs under `tmp/roundhouse/logs/`:

- `deployment-20261002-storage-clone.log`: online snapshot and manifest.
- `deployment-20261002-c-pack-bind.log`: final export.
- `deployment-20261002-linux-c-pack-bind-build.log`: final Linux image.
- `deployment-20261002-kamal-deploy-r2.log`: initial healthy deployment.
- `deployment-20261002-kamal-full-gc.log`: runtime GC configuration update.
- `deployment-20261002-verify-r2.log`: default-GC page checks and failed soak.
- `deployment-20261002-verify-full-gc.log`: passing full-marking page, browser,
  CSV and 2,100-read memory checks.
- `deployment-20261002-package-repro.log`: final packaging helper verified from
  fresh output (transpile 139.6 MiB/3.1s, prepare 74.7 MiB/1.2s, pack
  287.3 MiB/80.9s; frontend build also passed).
