# configuration

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

One object owning every configuration value of **this install of this app on
this machine** — the server URL to talk to, a log level, a polling interval,
whether the debug overlay is on. Declare the settings, read them, observe them,
and persist **only the ones the install actually changed**.

The scope is the `(client app, machine)` pair and nothing else. There is no user
parameter in the holder, in the store interface, or in the persisted format, by
design: a value that varies per *user* is a preference and belongs in
[`preferences/`](../preferences/readme.md), where it follows the account and
needs a session; a value that configures the *server* belongs in
`TomBaseServerConfiguration` (`tom_core_server`). Keeping them apart is what
makes "reading a client setting never needs a login" true rather than merely
usual.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomBaseClientConfiguration` | The holder. Declare settings in `declareSettings()`, then `load()` / `save()` / `reset(key)` / `resetAll()`. Is a `TomObservable` **and** observes each of its settings, so one observer sees every change. |
| `TomSetting<T>` | One addressable setting, and a `TomObject<T>` — so `~`/`\|`/`<<`/`call()`, `addObserver` and `TomObservingWidget` all work on it unchanged. Adds `key` (the dotted identity), `declaredDefault`, `baseline`, `isOverridden` and `reset()`. Constructed only by the holder's four `*Setting` methods. |
| `TomClientConfigurationStore` | Where overrides are persisted: `read()` and `write()`, and deliberately nothing else — writing an empty map *is* clearing. Two methods is the whole cost of adapting a new backend. |
| `TomMemoryClientConfigurationStore` | Persists nothing beyond the process — for tests, examples, and clients that keep no machine-local state. Not a fallback for platforms lacking a real backend: a store that silently forgets is worse than a loud one. |
| `TomFileClientConfigurationStore` | A JSON file holding the override map, selected by conditional export: the real `dart:io` store where there is a filesystem, and a variant that **throws from its constructor** where there is not. |
| `TomClientConfigurationException` | Six stable dotted codes: `client_configuration.store.not_configured`, `.value.type_mismatch`, `.key.duplicate`, `.key.unknown`, `.store.unsupported_platform`, `.store.invalid_content`. A subtype of `TomClientException`, so one `is` check separates a configuration failure from any other client-side error. |
| `coerceSettingValue<T>` | Reads a loosely-typed store or YAML value as a `T`, or throws `.value.type_mismatch`. |

## Quick start

```dart complete
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

Future<void> main() async {
  // The values shipped with the app.
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from({'client.refresh.seconds': 30}),
  );

  final config = AppConfiguration(store: TomMemoryClientConfigurationStore());

  print(~config.refreshSeconds); // 30 — the shipped value beats the declared 60
  print(~config.serverUrl);      // the declared default; no shipped value

  await config.load();     // adopt this install's persisted overrides
  config.darkMode | true;  // field observers fire; so do holder observers
  await config.save();     // persists {'client.ui.darkMode': true} — only that
}
```

`declareSettings` is called from the constructor, mirroring
`TomClass.prepareForSelfObservation`. It exists because Dart field initialisers
cannot call instance methods — so `stringSetting(...)` cannot appear in one —
and because it makes the declaration set **complete by the end of
construction**, which is what lets `settings`, `save` and `resetAll` be
exhaustive rather than "exhaustive so far".

## Resolution order

A setting's value is, highest precedence first:

1. the **persisted override** — what this install last saved;
2. the **shipped config-resources value** for the key
   (`TomConfigResourceProvider`);
3. the **declared default** at the declaration site.

Layers 2–3 are the `baseline`, resolved once at declaration time; `isOverridden`
is simply "current value differs from baseline", and that is exactly the set
`save()` writes. Nothing else tracks dirtiness.

**Only layer 1 is persisted.** A key the install never changed is re-resolved at
every start, so shipping a new default in an app update actually reaches installs
that never touched that key — which persisting the full value set would prevent,
freezing the shipped defaults at the moment of the first save. Keys the current
build does not declare are carried forward untouched, so an older build during a
staged rollout cannot destroy a value it merely does not know about.

## What this module does not do

- **No validation.** The *type* is checked — `coerceSettingValue` throws
  `.value.type_mismatch` on a raw value that cannot be read as the declared type
  — but the *value* never is: a `TomSetting<int>` stores and serves a refresh
  interval of `-1`. There is no hook to add a check either, since settings are
  created only by the four `*Setting` methods. Range, format and enum constraints
  are the **caller's**, applied after `load()` or at the point of use.
- **No autosave.** Persisting is asynchronous, and a setter that starts an
  unawaited write gives the caller no way to know whether it landed, no way to
  handle its failure, and one write per keystroke when a settings screen is bound
  field by field. Call `save()` when the edit is complete.
- **No concurrency control.** `save()` re-reads the store to seed its
  carry-forward, which narrows but does not close the window: read-then-write is
  not atomic, so two holders saving at genuinely the same moment can still lose
  one another's last write. Nothing detects that.

## Choosing a store

The file store's `path` is the caller's choice, because only the app knows where
its machine-local state belongs — `path_provider`'s application-support
directory on a Flutter client (this package does not depend on it), a temporary
directory in a test. The file is written whole with write-then-rename, so a
failure part-way through leaves the previous content readable rather than a
truncated override map; it is **deleted** when the map becomes empty, so "no
file" and "empty object" do not become two ways to say the same thing.

On a target with no filesystem the conditional export selects a variant that
throws `.store.unsupported_platform` **from its constructor**. A settings screen
whose Save button appears to work and forgets everything on reload is a worse
outcome than a failure at startup, and only the app knows what the browser
equivalent should be. A client that genuinely wants no machine-local persistence
says so with `TomMemoryClientConfigurationStore`.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context. Full module
documentation: [`doc/configuration.md`](../../../../doc/configuration.md).
