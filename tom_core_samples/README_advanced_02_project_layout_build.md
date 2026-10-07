# Project layout, packages & build

*Part 02 of the Tom Core advanced-sample user guide — see the [guide index](README_advanced_sample.md#user-guide).*

This part is the practical companion to the [architecture](README_advanced_01_architecture.md):
how the eight packages are laid out on disk, how their pubspecs wire together,
why they are all `publish_to: none`, how reflection code is generated (and when a
regen is actually required), and the exact steps to build and run the whole
system locally.

## The eight packages on disk

All eight packages live side by side under `tom_core_samples/`:

```
tom_core_samples/
  README_advanced_sample.md      the hub: suite map + quickstart
  advanced_todo_domain/          shared reflected model (User, Project, TodoList, TodoItem)
  advanced_todo_contracts/       wire DTOs + typed service interfaces
  advanced_client_core/          Flutter-free authenticated HTTP client core (+ e2e runner)
  advanced_auth_server/          JWT auth issuer + /admin/* API   (HTTP 8081, auth_db 3307)
  advanced_app_server/           secured task-manager API         (HTTP 8080, app_db 3308)
  advanced_app_client/           end-user Flutter app (board + sharing + field grades)
  advanced_authadmin_client/     administrator Flutter console (users/roles/groups/grants)
  advanced_ops_server/           scheduled back-office work       (no port, app_db 3308)
```

Each package is an ordinary Dart/Flutter package with its own `pubspec.yaml`,
`README.md`, and `LICENSE`. The two clients are Flutter packages (they depend on
the Flutter SDK plus `tom_flutter_ui` / `tom_core_flutter`); the other six are
plain Dart packages.

## Pubspec wiring

Every package targets **Dart SDK `^3.10.0`** and is marked
**`publish_to: none`** (see below). The Tom dependencies are wired by **relative
`path:`** within the monorepo — `tom_core_kernel` / `tom_core_server` /
`tom_flutter_ui` resolve to `../../<pkg>` (two levels up out of
`tom_core_samples/` into `tom_ai/core` and `tom_ai/reflection`), and the
inter-sample dependencies resolve to sibling `../advanced_<pkg>` paths.

The dependency arrows (verified against the real `dependencies:` blocks) are:

| Package | Depends on (sample + Tom) |
| --- | --- |
| `advanced_todo_domain` | `tom_core_kernel`, `tom_reflection` |
| `advanced_todo_contracts` | `advanced_todo_domain` (+ kernel, reflection) |
| `advanced_client_core` | `advanced_todo_contracts`, `advanced_todo_domain` (+ kernel) |
| `advanced_auth_server` | `advanced_todo_contracts`, `advanced_todo_domain`, `tom_core_server` (+ kernel) |
| `advanced_app_server` | `advanced_todo_contracts`, `advanced_todo_domain`, `tom_core_server` (+ kernel) |
| `advanced_app_client` | `advanced_client_core`, `advanced_todo_contracts`, `advanced_todo_domain`, `tom_flutter_ui`, `tom_core_flutter` (+ kernel) |
| `advanced_authadmin_client` | `advanced_client_core`, `advanced_todo_contracts`, `tom_flutter_ui`, `tom_core_flutter` (+ kernel) |
| `advanced_ops_server` | `advanced_app_server`, `advanced_auth_server`, `advanced_todo_domain`, `tom_core_server` (+ kernel) |

`advanced_ops_server` is the only package that depends on **another server**, and
deliberately so: it operates on the app server's data through the app server's
own repositories, and resolves digest recipients through the auth server's
`UserRepository`. A second entity model over the same tables would make its
audit-chokepoint claim a claim about a copy nobody runs.

> **`path:` is the monorepo convention, not a workaround.** These are sibling
> packages built and versioned together inside one repository, so a relative
> `path:` is the correct wiring. This is distinct from the workspace rule that
> forbids `path:`/`pubspec_overrides.yaml` to paper over a *missing published API*
> in an external dependency — here the dependencies are co-developed, not
> released artifacts.

## Build order

The build order follows the dependency arrows bottom-up — a package can only be
built (and its reflection generated) after the packages it imports:

1. `advanced_todo_domain` (nothing sample-local beneath it)
2. `advanced_todo_contracts` (needs the domain)
3. `advanced_client_core` (needs the contracts)
4. `advanced_auth_server` and `advanced_app_server` (need contracts + domain; order between the two does not matter to the *build*, only at *runtime* — start auth first)
5. `advanced_app_client` and `advanced_authadmin_client` (need `advanced_client_core` + contracts)
6. `advanced_ops_server` (needs **both** servers, because it reuses their repositories)

`dart pub get` (or `flutter pub get` for the two clients) in each package resolves
the relative paths; running it bottom-up avoids resolving against a
not-yet-fetched sibling.

## `publish_to: none`

Every sample pubspec declares `publish_to: none`. The samples are **teaching
artifacts internal to the monorepo**, not pub.dev packages: they wire to Tom
packages by relative `path:`, they ship seeded demo accounts and a
`change-me-in-production` JWT secret, and they are meant to be read and run in
place, never depended on as a release. `publish_to: none` makes that explicit and
prevents an accidental `dart pub publish`.

## Reflection generation

Six of the eight packages reflect types; each has **exactly one reflection entry
point** and a `build.yaml` that emits a sibling `<entry>.reflection.dart`. Only
real entry-points (the servers' `bin/` and the clients' `lib/`) ship a **runtime**
seed; the two **libraries** carry a seed only for their own tests, rooted under
`test/` (G-REFL-1/2):

| Package | Entry point | Generated output | Kind |
| --- | --- | --- | --- |
| `advanced_todo_domain` | `test/run_all_tests.dart` | `test/run_all_tests.reflection.dart` | test-only |
| `advanced_todo_contracts` | `test/run_all_tests.dart` | `test/run_all_tests.reflection.dart` | test-only |
| `advanced_auth_server` | `bin/auth_server_start.dart` | `bin/auth_server_start.reflection.dart` | runtime |
| `advanced_app_server` | `bin/app_server_start.dart` | `bin/app_server_start.reflection.dart` | runtime |
| `advanced_app_client` | `lib/reflection_seed.dart` | `lib/reflection_seed.reflection.dart` | runtime |
| `advanced_authadmin_client` | `lib/reflection_seed.dart` | `lib/reflection_seed.reflection.dart` | runtime |
| `advanced_ops_server` | `bin/ops_server_start.dart` | `bin/ops_server_start.reflection.dart` | runtime |

(`advanced_client_core` reflects nothing of its own — it consumes the combined
client seed.)

**The single-seed rule.** The generated `initializeReflection()` *assigns* the
reflection data (last writer wins), so **exactly one seed's `initializeReflection()`
may run per program**. That is why each runnable (each server `bin/` entry, each
client) has *one* seed that must cover **every** reflected type the program
touches — including types that live in another package. The client seeds, for
example, import the shared `advanced_todo_domain` entities *and* the client-local
forms, because a `TomForm` is itself a reflected `TomClass` and `bind`/`save`
walk a form's fields through kernel reflection — so both the bound entities and
the forms themselves must be in the reflected graph. (The client seed imports
`advanced_todo_domain` for generator discovery but does **not** re-export it: the
domain is a library and ships no runtime seed, so the one authoritative
`initializeReflection()` a client runs is its own combined seed. The server tests
follow the same rule from the other direction — they bootstrap through the
server's own `bin/` seed, not a library seed, since the domain library ships no
seed of its own.)

**Regenerate only on signature changes.** Each package ships a
`reflection_generation.sh` that runs the generator flag-free:

```sh
# from the package root, e.g. advanced_todo_domain/
./reflection_generation.sh
# → dart run tom_reflection_generator
```

The invocation is **flag-free**: the generator's framework default scans the
current project only (scan `.`, non-recursive), so it needs no workspace registry
and no scan flag — it works standalone from the package root. The two Flutter
clients are no exception: their scripts pass no flags either, and their headers
warn *against* `--no-cache`, because on a Flutter package it forces a full live
analysis of the entire Flutter closure under the analyzer and takes 20+ minutes.
They run with the summary cache **enabled** — the fast path. The escape hatch,
if a cache is ever suspected of being stale, is `--rebuild-cache`, which the
scripts forward through `"$@"`. A regen is required **only when a reflected
type's signature changes** — a field/method/annotation added, removed, or
retyped on a `@tomReflector`/`@tomService` type, or a new reflected type added
to a seed. Editing *bodies* or non-reflected code needs no regen. The
`*.reflection.dart` outputs are **generated, do-not-edit** files; regenerate
them, never hand-edit, and take them as a complete set from one generator run
(never hand-merge them).

## Running build_runner

The reflection script above is the supported path and is preferred. If you build
through `build_runner` directly instead (the two reflecting libraries declare
`build_runner` + `tom_reflection_generator` as dev-deps), run it from the package
root:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Either path produces the same `<entry>.reflection.dart`. Use
`reflection_generation.sh` unless you have a reason to drive `build_runner`
yourself — it encodes the correct flag-free invocation and target, and forwards
`--rebuild-cache` on the rare occasion you need it.

## Local run: env, Docker compose, flutter run

Each server owns its database via a `docker-compose.yaml` plus a `.env.example`
you copy to `.env`. The two databases bind **distinct host ports (3307 / 3308)**
so both servers — and a host-local MariaDB — coexist. The auth server's
`.env.example` shows the shape (db image/host/port/name/credentials, plus an
`env=dev|int|prod` selector that picks the matching
`assets/config-resources_<env>.yaml` overlay **and** the runtime environment,
both resolved from the same value). Each file declares only what something
reads: the HTTP port is a `_defaultPort` constant in the boot file, applied only
where the configuration merge left the field at `0`, and the JWT key material is
three commented-out variables — `JWT_SHARED_SECRET_KEY`, `JWT_RSA_PRIV_KEY`,
`JWT_RSA_PUB_KEY`, the environment spellings of the `jwtSharedSecretKey`,
`jwtRsaPrivKey` and `jwtRsaPubKey` configuration fields. Left commented, both
servers fall back to the framework's **bundled sample keys**, which is what makes
them trust each other out of the box; set `JWT_SHARED_SECRET_KEY` to the same
value in both and the trust rests on a secret you chose, set it in one only and
the app server rejects the auth server's tokens. The fallback is refused outright
outside a development or test environment — which is why `env=dev` is not
optional here (part [06](README_advanced_06_authentication.md)).

**A `SCREAMING_SNAKE_CASE` variable reaches the `lowerCamelCase` configuration
field of the same name**, so `JWT_SHARED_SECRET_KEY` and `jwtSharedSecretKey` are
two spellings of one key. That is a general rule of the merge, not something
these servers wire up.

To move a port, override the `port` configuration key from any of the merge's
sources — a config asset, the OS environment, the `.env`, or a command-line
`port=9081`, **undashed**. The conventional `--port=9081` does nothing: a key is
the argument text before the first `=`, dashes included, so the dashed form
fills a key named `--port`, which matches no field and is dropped without a
diagnostic. That matters more here than in a single-server sample, because these
two servers must stay on *different* ports (8081 and 8080) — so the override is
actually reached for, and the dashed form fails as a port conflict on the other
server rather than as a rejected argument.

The end-to-end run is four moves (full commands in the hub's
[Run the whole thing](README_advanced_sample.md#run-the-whole-thing)):

1. **Databases** — `cp .env.example .env` then `docker compose up -d` the db
   service in each server package; first boot seeds the schema (the auth server
   also seeds the demo accounts and the grant matrix).
2. **Auth server first** — `dart run bin/auth_server_start.dart` (HTTP `:8081`);
   it mints tokens and owns the grant matrix.
3. **App server next** — `dart run bin/app_server_start.dart` (HTTP `:8080`,
   `GET /health → 200`); it verifies those tokens and reads grants. Each server
   runs from its own package root so relative migration/asset paths resolve.
4. **Clients** — `flutter run` each client. With no dart-defines they target the
   local servers by default, reading their URLs from the `AdvancedClientConfig`
   config bean:

   ```sh
   # end-user app — from advanced_app_client/
   flutter create --empty --platforms=macos .   # once; or linux, windows
   flutter run

   # admin console — from advanced_authadmin_client/
   flutter create --empty --platforms=macos .   # once; or linux, windows
   flutter run
   ```

   Neither client ships platform folders; each README's *Before the first run*
   explains the step and the macOS network entitlement the live stack needs.

Launched with `--dart-define=TEST_MODE=true`, either client boots on a **seeded
in-memory backend** instead — the opt-in offline mode, and exactly the fake the
socket-free widget tests inject (part
[12](README_advanced_12_testing_integration.md)). Each client's fake seeds its
own accounts, and the two sets are not the same:

- **End-user app** (`in_memory_app_backend.dart`) — five, signed into as
  <!-- account-roster: app-offline -->`alice`, `bob`, `carol`, `dave`, `erin`, keyed `u-alice` … `u-erin`<!-- /account-roster -->. There is
  no `admin` here. `dave` and `erin` are what make the offline second-factor
  demo reachable: `dave` is enrolled at seed time, holding the same TOTP secret
  the auth server's `[005]-auth_two_factor_seed` migration writes, so a code
  that satisfies the offline backend satisfies the live one; `erin` owes a
  factor and holds none, so her login is *offered* enrolment rather than
  challenged for it.
- **Admin console** (`in_memory_admin_backend.dart`) — four, signed into as
  <!-- account-roster: admin-offline -->`admin`, `alice`, `bob`, `carol`, keyed `u-admin` … `u-carol`<!-- /account-roster -->. `admin` is the
  one the console cannot do without: its endpoints are gated on
  `TomRoleAccess(['admin'])`.

Those are the fakes' own ids, and they exist only inside the client process.
The hub's **Seeded live accounts** table, under [Run the whole
thing](README_advanced_sample.md#run-the-whole-thing), is a different id space —
the `auth_db` rows the `[002]`, `[003]` and `[005]` seed migrations write,
which is what the servers authenticate against.

## Primary sources

- The eight `pubspec.yaml` files; each package's `build.yaml`, `reflection_generation.sh`, and reflection entry/seed.
- [`README_advanced_sample.md`](README_advanced_sample.md) — the Repository-layout tree and the [Run the whole thing](README_advanced_sample.md#run-the-whole-thing) quickstart.

---

← Prev: [01 · Full-stack architecture](README_advanced_01_architecture.md) · Next: [03 · Domain model & reflection](README_advanced_03_domain_reflection.md) →
