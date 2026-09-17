# Configuration Module

The **machine-scoped** configuration of a client app: one holder object that
owns every setting of this install, resolves each from the shipped config
resources, adopts the install's persisted overrides at startup, and persists
back **only what the install actually changed**.

Where [`TomProperty<T>`](resources.md) reads a single config key eagerly and
immutably, a `TomBaseClientConfiguration` gives the same values a lifecycle:
they are observable, writable, persistent, and addressable as a set.

## Table of Contents

- [Overview](#overview)
- [Scope](#scope)
- [Quick Start](#quick-start)
- [Resolution Order](#resolution-order)
- [Core Components](#core-components)
- [Observation](#observation)
- [Persistence](#persistence)
- [Error Keys](#error-keys)
- [Limitations](#limitations)
- [Dependencies](#dependencies)

---

## Overview

| Type | Role |
| ---- | ---- |
| `TomBaseClientConfiguration` | Base class for a client app's settings holder |
| `TomSetting<T>` | One observable setting — a `TomObject<T>` plus its key and baseline |
| `TomClientConfigurationStore` | Where overrides are persisted (two methods) |
| `TomMemoryClientConfigurationStore` | Process-lifetime store — tests, examples, deliberately stateless clients |
| `TomFileClientConfigurationStore` | JSON file on the local filesystem (native targets) |
| `TomClientConfigurationException` | Failures of this module, with stable dotted keys |

## Scope

A client configuration holds the settings of **(this app, this machine)** — the
server URL to talk to, a log level, a polling interval, whether the debug
overlay is on.

There is no user parameter in the holder, in the store interface, or in the
persisted format, by design:

| Varies by | Belongs to |
| --------- | ---------- |
| client install / machine | **this module** |
| user (device-local) | a user-preferences holder — different lifecycle, needs a session |
| user (server-persisted) | a user-profile holder — syncs across devices |
| server deployment | `TomBaseServerConfiguration` (`tom_core_server`) |

Mixing those scopes into one holder is what turns a settings class into a junk
drawer, and it breaks the guarantee that reading a client setting never
requires a login.

Per-field **validation** is likewise not the holder's job, and nothing else in
the module does it either. The *type* is checked — a raw value that cannot be
read as the declared type raises `client_configuration.value.type_mismatch` —
but the *value* never is: a `TomSetting<int>` stores and serves a refresh
interval of `-1`, a `TomSetting<String>` an empty server URL. There is no hook
to add a check, because `TomSetting`'s constructor is private and settings are
created only by the holder's `*Setting` methods. Range, format and enum
constraints are the **caller's** — applied after `load()`, or at the point of
use.

## Quick Start

```dart
import 'package:tom_core_flutter/tom_core_flutter.dart';

class AppConfiguration extends TomBaseClientConfiguration {
  AppConfiguration({super.store});

  late final TomSetting<String> serverUrl;
  late final TomSetting<int> refreshSeconds;
  late final TomSetting<bool> darkMode;

  @override
  void declareSettings() {
    serverUrl = stringSetting('client.server.url', 'https://api.example.com');
    refreshSeconds = intSetting('client.refresh.seconds', 60);
    darkMode = boolSetting('client.ui.darkMode', false);
  }
}

final config = AppConfiguration(
  store: TomFileClientConfigurationStore('$supportDir/client_config.json'),
);
await config.load();       // adopt this install's overrides

config.darkMode | true;    // observers fire, per field and holder-wide
await config.save();       // persist the overrides — and only those
```

`declareSettings()` is called by the base constructor. It exists because Dart
field initialisers cannot call instance methods, and because it makes the
declaration set **complete by the end of construction** — which is what lets
`settings`, `save()` and `resetAll()` be exhaustive.

Only four value types can be declared — `String`, `int`, `double`, `bool` —
exactly those that survive a JSON round-trip through a store.

## Resolution Order

Highest precedence first:

1. the **persisted override** — what this install last saved;
2. the **shipped config-resources value** for the key
   (`TomConfigResourceProvider`);
3. the **declared default** at the declaration site.

Layers 2–3 form the setting's `baseline`, resolved once at declaration time.
A setting is *overridden* exactly when its value differs from that baseline —
and that is precisely the set `save()` persists.

External values are loosely typed (a JSON store, a YAML config file), so the
readings with exactly one sensible interpretation are accepted: the exact type,
`int` → `double`, and `String` → `int`/`double`/`bool` when it parses. Anything
else throws `client_configuration.value.type_mismatch` naming the key rather
than quietly falling back to the default — a fallback would hide a config typo
behind behaviour that merely looks correct.

## Core Components

### `TomBaseClientConfiguration`

| Member | Purpose |
| ------ | ------- |
| `declareSettings()` | **Abstract.** Declare every setting; called from the constructor |
| `stringSetting` / `intSetting` / `doubleSetting` / `boolSetting` | Declare a setting under a dotted key with a default |
| `load()` | Adopt the persisted overrides (idempotent) |
| `save()` | Persist the overrides, and only those |
| `store` | The override store; may be wired after construction. Changing it discards the loaded snapshot, keeps the settings — call `load()` to adopt the new store |
| `settings` / `settingFor(key)` | The declared settings, addressable as a set |
| `isOverridden(key)` / `hasOverrides` | Whether the install has changed something |
| `reset(key)` / `resetAll()` | Drop overrides in memory (call `save()` to make it stick) |

### `TomSetting<T>`

A `TomObject<T>` — so `~`, `|`, `<<`, `call()`, `addObserver` and
`TomObservingWidget` all work on it unchanged — plus:

- `key` — the dotted configuration key. This, not the Dart field name, is the
  setting's identity: it is what the config resources and the store are keyed
  by.
- `declaredDefault` — the default written at the declaration site.
- `baseline` — the value when the install has not overridden it.
- `isOverridden`, `reset()`.

### Stores

`TomClientConfigurationStore` is deliberately two methods — `read()` and
`write(values)`. There is no `clear` (writing an empty map *is* clearing) and no
per-key accessor, so adapting a new backend (`shared_preferences`, browser local
storage, a keychain) costs two methods.

`TomFileClientConfigurationStore` writes JSON via write-then-rename, so a
failure part-way through leaves the previous content readable rather than a
truncated override map. An empty write deletes the file. It is selected by
conditional export: on a target without `dart:io` the same name resolves to a
variant that **throws on construction** with
`client_configuration.store.unsupported_platform` rather than silently
degrading — a settings screen whose Save button appears to work but forgets
everything is worse than a failure at startup.

## Observation

Both granularities are live at once:

- **per field** — observe the `TomSetting`; a `TomObservingWidget` bound to it
  rebuilds on that one setting;
- **whole holder** — observe the holder; it observes each of its settings and
  re-emits, so one observer sees every change.

`load()` and `resetAll()` emit **one** holder notification for the whole
operation, not one per setting. Per-field observers still fire per field.

That survives nesting. A screen batching a multi-setting edit around a reload
mutes the holder itself and calls `load()` inside its own batch; because
`TomObservable.mute` counts depth rather than setting a flag, the load's release
does not free the caller's, and the screen still gets the one rebuild it asked
for. Were it a flag, the caller's suppressed writes would escape during the
load, the holder would come back unmuted without anyone asking, and every later
write in the batch would notify immediately. The property belongs to the kernel,
so `test/configuration_test.dart` asserts the consequence here rather than
assuming it.

> Observers are held by weak reference. Retain the observer returned by `>>`
> for as long as you want notifications, or it will silently stop firing.

## Persistence

**Only overrides are stored, never the full value set.** A setting the install
never changed is re-resolved from the shipped config resources at every start,
so shipping a new default in an app update actually reaches installs that never
touched that key. Persisting everything would freeze the shipped defaults at the
moment of the first save.

Keys in the store that the running build does not declare are **carried
forward** untouched — a build that has dropped a setting, or an older build
during a staged rollout, must not destroy an install's value for a key it does
not know.

Carry-forward reads the store at `save()` rather than reusing what `load()`
found, so it protects the keys of *the store being written* at the moment it is
written. That matters in two cases the snapshot would get wrong: a holder that
has been pointed at a **different store** must not deposit the first store's
keys into the second (nor destroy the second's own), and a key written by
**someone else since this holder loaded** must be carried forward rather than
deleted — which is exactly the loss the mechanism exists to prevent.

**Changing the store discards the loaded snapshot but not the settings.** A
snapshot describes the store it came from, so assigning a different store drops
it; the settings keep their current values, because a swap is not a load. Call
`load()` to adopt the new store's overrides.

**Saving is explicit.** There is no autosave: persisting is asynchronous, and a
setter that silently starts an unawaited write gives the caller no way to know
whether it landed, no way to handle failure, and one write per keystroke when a
settings screen is bound field-by-field.

## Error Keys

Every failure is a `TomClientConfigurationException` (a `TomClientException`)
with a stable dotted `key`, so callers branch on the code rather than on message
text:

| Key | Raised when |
| --- | ----------- |
| `client_configuration.store.not_configured` | `load()`/`save()` with no store wired |
| `client_configuration.value.type_mismatch` | A config or stored value cannot be read as the declared type |
| `client_configuration.key.duplicate` | The same key is declared twice |
| `client_configuration.key.unknown` | `reset`/`isOverridden` on an undeclared key |
| `client_configuration.store.unsupported_platform` | A file store on a target without a filesystem |
| `client_configuration.store.invalid_content` | The store holds content that is not a readable override map |

## Limitations

- **Four value types.** `String`, `int`, `double`, `bool`. A structured value
  belongs in the config resources, not in a per-install override.
- **The baseline is fixed at declaration.** Replacing the config provider
  afterwards does not move it — a baseline that shifted under a running app
  would make "is this overridden?", and therefore what gets persisted, depend on
  when you asked.
- **No web file store.** See `client_configuration.store.unsupported_platform`
  above; supply a browser-appropriate store explicitly.
- **No per-field validation, and no hook to add one.** The type is enforced, the
  value is not: `-1` is an acceptable refresh interval and `''` an acceptable
  server URL. `TomSetting`'s constructor is private, so a validating subclass
  cannot be substituted — range, format and enum checks are the caller's, after
  `load()` or at the point of use.
- **Concurrent saves are not atomic, and a collision is not detected.** `save()`
  re-reads the store before writing it, so a holder preserves keys another
  writer has added — but read-then-write is not a single operation. Two holders
  saving at genuinely the same moment can still lose one another's last write,
  and nothing notices: there is no version stamp in the persisted document and
  `save()` cannot fail on a conflict. The exposure is one store round-trip
  rather than the whole session, which makes sharing a location workable but not
  safe against true simultaneity.

---

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:convert` | dart | `file_configuration_store_io.dart` | `jsonDecode`, `jsonEncode` |
| `dart:io` | dart | `file_configuration_store_io.dart` | `File` |
| `tom_core_kernel` | package | `client_configuration.dart`, `client_configuration_store.dart` | `TomObservable` / `TomObject` (the observation substrate), `TomConfigResourceProvider` (the shipped config layer), `TomException` |
| [little_things](little_things.md) | module | `client_configuration_store.dart` | `TomClientException` |
