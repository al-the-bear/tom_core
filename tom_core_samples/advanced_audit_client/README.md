# advanced_audit_client

The auditor's Flutter application for the **advanced Tom Core full-stack
sample** (see [`../README_advanced_sample.md`](../README_advanced_sample.md)).

Signs in with the `auditor` role and works the audit trail through the
framework's audit-report API (`tomAuditReportsApi`), which the app server
serves under `/audit-reports` (through `advanced_client_core`'s
`AuditReportsClient`): it asks the trail questions across every writer that
records into `app_db`, saves questions with a schedule, recipients and a
format, and has a saved question delivered — by the ops server's delivery
pass — as a CSV, XLSX or PDF export by email.

> **Part of the [Tom Core user guide](../README_advanced_sample.md#user-guide).**
> The module it drives is documented in
> [`tom_core_server/doc/audit_reports.md`](../../tom_core_server/doc/audit_reports.md).

**There is no `example/` directory and no `doc/` folder, and both absences are
deliberate: this package is itself the runnable example, and a sample has no
consumers who need its surface mirrored — see [the suite map](../README.md) for
that decision, which is the same for all eighteen sample packages.** This
README is the package's one description of its surface. It is one of the ten
`advanced_*` packages that together form the full-stack sample. What to run
instead:

- **`lib/main.dart`** — the bootstrap: reflection, the client platform, the
  client configuration, then the application over the backend the launch flag
  selects.
- **`flutter run --dart-define=TEST_MODE=true`**, once a platform folder exists
  ([Before the first run](#before-the-first-run)) — the whole application
  offline over `InMemoryAuditBackend`, with no server behind it. With no
  dart-defines it drives the live servers instead
  ([Against the live servers](#against-the-live-servers)).
- **The widget suite** under [Tests](#tests).

[The family's index](../README_advanced_sample.md#the-ten-packages) says which of the ten carry an `example/`, and why.

## Before the first run

The package ships no platform folders: they are generated scaffolding, and the
sample carries only its own source. Flutter will not run a project on a
platform it has no folder for, so generate the one you run on, once, from this
directory:

```sh
flutter create --empty --platforms=macos .   # or linux, or windows
```

`--empty` matters. Without it `flutter create` also writes a counter-app
`test/widget_test.dart` that pumps a `MyApp` this package does not have, and the
suite stops compiling. The command leaves `lib/`, `pubspec.yaml` and this README
alone, and what it adds — the platform folder, `.metadata`, IDE files — is
gitignored.

On macOS the app is sandboxed, and the generated
`macos/Runner/DebugProfile.entitlements` allows incoming connections only. The
offline mode needs nothing more; to reach the live servers, add
`<key>com.apple.security.network.client</key><true/>` to that file first.

## Layout

| File | What it holds |
| ---- | ------------- |
| `lib/main.dart` | The bootstrap, and the choice between the live and the in-memory backend (`TEST_MODE`). |
| `lib/app.dart` | The screens: sign-in; **Ask** — actor, target, action, outcome, a window (last day, week or month, or all time) and the writers to read as chips, the answer as a list with each record's writer and chain position; **Save as question** — name, recipients, a schedule (not scheduled, daily, Mondays, the first of the month, all at 06:00 UTC) and a format; **Saved questions** — tap to answer one now, deliver one at the next pass, delete one. |
| `lib/backend.dart` | `AuditBackend`, the seam: `LiveAuditBackend` over `AuthClient` and `AuditReportsClient`, and `InMemoryAuditBackend` over a fixed trail of two writers. |
| `lib/reflection_seed.dart` | The reflection root for the wire DTOs; regenerate with `./reflection_generation.sh`. |

## Against the live servers

The live backend signs in at the auth server (`http://localhost:8081`) and
calls the app server (`http://localhost:8080`), at the addresses
`AdvancedClientConfig` names. Sign in as **`audrey` / `audrey-pass`**, the
`@dev,test` seed's auditor (`[010]` in the auth server's migrations); an account
without the `auditor` role is refused at sign-in, because every route of the
API answers it as if it did not exist, and an account with a second factor is
refused because this application does not offer one.

The API reads `app_db`'s audit trail and keeps the questions beside it. Both
tables come from the ops server's migrations (`[100]`, `[101]`), so apply them once
the app server is up:

```sh
(cd ../advanced_ops_server && dart run bin/ops_server_start.dart --migrate-only)
```

A question marked for delivery is delivered by the ops server's pass, which
runs every minute while `advanced_ops_server` is running; the app server only
answers and marks. The trail holds what the ops server's jobs record — its
retention deletes, its refusals — and each delivery.

## Tests

`test/audit_app_test.dart` (AAC-1 to AAC-4) drives the application over
`InMemoryAuditBackend`: a wrong password refused with its message; audrey
asking across both writers and narrowing by actor; a question saved from the
ask form, listed, marked for delivery and deleted; and signing out. The API
itself is exercised live by `advanced_client_core`'s
`test/audit_reports_client_integration_test.dart`, which the cross-tier runner
runs.

## Dependencies

| Dependency | For |
| ---------- | --- |
| `flutter` | The application |
| `tom_core_flutter` | The client platform utilities set at bootstrap |
| `tom_core_kernel` | The audit-report contract's DTOs and reflection |
| `advanced_client_core` | `AuthClient`, `AuthorizedHttp`, `HttpJsonTransport`, `AdvancedClientConfig` and `AuditReportsClient` |
| `advanced_todo_contracts` | The login DTOs |
| `flutter_test`, `flutter_lints` | The widget suite and analysis (dev) |
| `build`, `build_runner`, `tom_reflection_generator` | The reflection seed (dev) |
