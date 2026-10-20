# tom_core_settings

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Settings and secrets for Tom applications — the key port for encrypted
containers, the platform secret-store port, the device settings file and the
bootstrap that mints its settings key, the user's identity, and the registered
storage locations with forgetting one. Platform-neutral: no `dart:io`, no
container format, no platform plugin.

## Overview

An application with encrypted documents holds two kinds of settings:

- **What follows the person** — tokens, document keys, identity, registered
  locations — kept in an encrypted settings container whose format the
  application chooses.
- **What describes the machine** — the window layout, the log's location, the
  cache quota — kept in a plain YAML **device settings** file
  (`TomDeviceSettings`) that is readable when nothing else works, never synced
  and never a secret.

The settings container needs a key, and its key cannot live inside it. So a
device holds **one** secret outside both, in the platform secret store
(`TomSecretStore`), with only its *handle* in device settings.
`TomSettingsKeyBootstrap` mints that secret on first launch and finds it again
afterwards; a wiped keychain re-mints the secret under the same handle, and a
keychain that cannot be asked at all is raised as `TomSecretStoreException`
naming the call that failed.

The **key port** states a container key as material (`TomKeyMaterial`: a
passphrase, a key file's bytes, or a pointer to a key file), registers keys per
container with a default behind them (`TomKeyRegistry`), and persists them
between sessions (`TomKeyStore`). A container library's binding turns material
into its own credentials; nothing above it names that library.

**Locations** (`TomStorageLocation`, `TomLocationRegistry`) are a convenience
list of places to offer, never an access-control list. `TomLocationForgetting`
removes one together with every trace this device keeps for it — per-file key
overrides, cache blobs and records, unpushed journal entries — after `survey`
has said what that would remove.

## Installation

The package is consumed by path inside this workspace:

```yaml
dependencies:
  tom_core_settings:
    path: ../../tom_ai/core/tom_core_settings
```

Dart SDK `^3.10.0`. No Flutter dependency.

## Features

| Type | What it does |
| ---- | ------------ |
| `TomDeviceSettings` | The device settings file: an open registry of keys written back whole, typed accessors for the settings-key handle, the log's path and level and the cache's quota and sealing, and one serialized write queue. |
| `TomSettingsKeyBootstrap` | Mints the device's settings key into the secret store and records its handle; answers a `TomSettingsKey`. |
| `TomSecretStore` | The platform secret-store port (implements `tom_core_storage`'s `TomCacheKeyStore`); `TomInMemorySecretStore` for tests. |
| `TomSecretStoreException` | A secret store that could not answer, naming the step (`TomSecretStoreStep`) and keeping the cause. |
| `TomKeyMaterial` | A container key: passphrase, key-file bytes, key-file locator; `isResolvable` and `isEmpty` kept apart. |
| `TomKeyRegistry` | The keys a session tries, by container, with a default; `TomMemoryKeyRegistry` opens nothing. |
| `TomKeyStore` | Keys persisted between sessions: two defaults and per-file overrides; `TomInMemoryKeyStore`. |
| `TomIdentity` | The display name and stable author id content is attributed to, with the `unknown` sentinel. |
| `TomStorageLocation`, `TomLocationRegistry` | Registered locations, keyed by locator; `TomInMemoryLocationRegistry` remembers for the session. |
| `TomLocationForgetting` | `survey` and `forget` a location and its traces (`TomLocationTraces`, `TomForgottenLocation`). |

## Quick start

```dart
import 'package:tom_core_settings/tom_core_settings.dart';
import 'package:tom_core_storage/io.dart';

Future<void> main() async {
  final device = TomDeviceSettings(
    locator: 'device.yaml',
    storage: const TomLocalFileSystemStorage(),
  );
  // A platform keychain in an application; in memory here.
  final secrets = TomInMemorySecretStore();

  final key = await TomSettingsKeyBootstrap(
    device: device,
    secrets: secrets,
  ).ensure();
  // key.secret opens the settings container; key.handle is in device.yaml.

  device.cacheQuotaBytes = 256 << 20;
  await device.save();
}
```

## Limits

- **No container format.** The encrypted settings container, and turning key
  material into its credentials, belong to a container binding the application
  supplies.
- **No platform secret store.** The keychain implementation is the host's —
  a Flutter host binds the platform keychain behind `TomSecretStore`.

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `tom_basics` | runtime | the diagnostics level, and the YAML emitter and reader |
| `tom_core_storage` | runtime | the storage port the device file is committed through; the cache and journal a forgotten location is scrubbed from |
| `uuid` | runtime | the handle a minted settings key is stored under |
| `yaml` | runtime | reading the device file |
| `meta` | runtime | `@visibleForTesting` |
| `test`, `lints` | dev | the suite (with `tom_github_api`'s in-memory GitHub from `package:tom_github_api/testing.dart`, and `http`) |

## Status

Version **0.1.0**. `dart test` runs the unit suite — the device file and its
write queue, the bootstrap against a failing and a wiped keychain, the key port,
forgetting a location over an in-memory GitHub — and a walk of the import
closure plus a dart2js compile, which keep the package platform-neutral.
